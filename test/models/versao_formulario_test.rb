require "test_helper"

# Versões de formulário: o rascunho muda; a publicada nunca muda nem sai.
class VersaoFormularioTest < ActiveSupport::TestCase
  setup do
    @formulario = formularios(:acompanhamento)
    @publicada = versoes_formulario(:acompanhamento_v1)
  end

  test "a versão publicada não muda nem é apagada, nem por update_columns" do
    assert @publicada.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { @publicada.update!(estrutura: estrutura_de_formulario) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { @publicada.update!(publicada_em: 1.day.ago) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { @publicada.destroy }
    assert_raises(ActiveRecord::ReadOnlyRecord) { @publicada.update_columns(estrutura: estrutura_de_formulario.to_json) }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { @publicada.numero = 9 }
  end

  test "publicar exige a definição completa; o rascunho continua rascunho se não der" do
    rascunho = @formulario.versoes.create!(numero: 2, estrutura: estrutura_de_formulario(finalidade: nil))

    erro = assert_raises(ActiveRecord::RecordInvalid) { rascunho.publicar!(por: users(:admin)) }
    assert_includes erro.record.errors.full_messages, "Finalidade: falta preencher."
    assert rascunho.rascunho?
    assert rascunho.reload.rascunho?
    assert_equal @publicada, @formulario.reload.versao_publicada
  end

  test "publicar congela a versão, registra quem publicou e a torna a que se preenche" do
    rascunho = @formulario.versoes.create!(numero: 2, estrutura: estrutura_de_formulario)

    rascunho.publicar!(por: users(:admin))
    assert rascunho.reload.publicada?
    assert rascunho.readonly?
    assert_equal users(:admin), rascunho.publicada_por
    assert_equal rascunho, @formulario.reload.versao_publicada
    assert_raises(ActiveRecord::RecordNotSaved) { rascunho.publicar!(por: users(:admin)) }
  end

  test "publicar pede o autor" do
    rascunho = @formulario.versoes.create!(numero: 2, estrutura: estrutura_de_formulario)

    assert_raises(ActiveRecord::RecordInvalid) { rascunho.publicar!(por: nil) }
    assert rascunho.reload.rascunho?
  end

  test "publicar um rascunho que mudou depois de lido é recusado (lock_version)" do
    rascunho = @formulario.versoes.create!(numero: 2, estrutura: estrutura_de_formulario)
    VersaoFormulario.find(rascunho.id).update!(estrutura: estrutura_de_formulario(titulo: "Mudou em outra aba"))

    assert_raises(ActiveRecord::StaleObjectError) { rascunho.publicar!(por: users(:admin)) }
    assert rascunho.reload.rascunho?
  end

  test "um rascunho só por formulário, garantido pelo banco" do
    @formulario.versoes.create!(numero: 2, estrutura: estrutura_de_formulario)

    assert_raises(ActiveRecord::RecordNotUnique) do
      VersaoFormulario.insert!({ formulario_id: @formulario.id, numero: 3, estrutura: estrutura_de_formulario.to_json,
                                 created_at: Time.current, updated_at: Time.current })
    end
  end

  test "o banco recusa estrutura que não é JSON e versão com autor mas sem data de publicação" do
    inserir = ->(colunas) { VersaoFormulario.connection.execute("INSERT INTO versoes_formulario (#{colunas.keys.join(', ')}) VALUES (#{colunas.values.join(', ')})") }
    agora = "NOW()"

    assert_raises(ActiveRecord::StatementInvalid) { inserir.(formulario_id: @formulario.id, numero: 4, estrutura: "'{nao e json'", created_at: agora, updated_at: agora) }
    assert_raises(ActiveRecord::StatementInvalid) do
      inserir.(formulario_id: @formulario.id, numero: 5, estrutura: "'{}'", publicada_por_id: users(:admin).id, created_at: agora, updated_at: agora)
    end
    assert_raises(ActiveRecord::StatementInvalid) { inserir.(formulario_id: @formulario.id, numero: 0, estrutura: "'{}'", created_at: agora, updated_at: agora) }
  end

  test "só grava estrutura aceita pelo motor, e grava a forma canônica" do
    invalida = @formulario.versoes.build(numero: 2, estrutura: estrutura_de_formulario([ { "chave" => "x", "texto" => "X", "tipo" => "arquivo" } ]))
    assert_not invalida.save
    assert_includes invalida.errors.full_messages.join, "tipo de pergunta desconhecido"

    versao = @formulario.versoes.create!(numero: 2, estrutura: estrutura_de_formulario(titulo: "  Título‮  ", descricao: ""))
    gravada = JSON.parse(versao.read_attribute_before_type_cast(:estrutura))
    assert_equal "Título", gravada["titulo"]
    assert_not gravada.key?("descricao")
    assert_equal 100, gravada["secoes"].first["perguntas"].first["maximo"]
  end

  test "a definição publicada é lida uma vez; a do rascunho acompanha as mudanças" do
    assert_same @publicada.definicao, VersaoFormulario.find(@publicada.id).definicao

    rascunho = @formulario.versoes.create!(numero: 2, estrutura: estrutura_de_formulario)
    assert rascunho.definicao.rascunho?
    rascunho.estrutura = estrutura_de_formulario(titulo: "Outro título")
    assert_equal "Outro título", rascunho.definicao.titulo
  end

  test "rascunho sem perguntas e sem finalidade é aceito, como começa no gerador" do
    rascunho = @formulario.versoes.create!(numero: 2, estrutura: { "titulo" => "Começo", "secoes" => [] })

    assert rascunho.persisted?
    assert_empty rascunho.definicao.perguntas
  end

  test "rascunho sem notificações pode ser descartado; versão com notificações não" do
    rascunho = @formulario.versoes.create!(numero: 2, estrutura: estrutura_de_formulario)
    assert rascunho.destroy

    assert_not @publicada.avaliacoes_clinicas.empty?
    assert_raises(ActiveRecord::ReadOnlyRecord) { @publicada.destroy }
    sem_notificacoes = publicar_formulario("sem_notificacoes").versao_publicada
    assert_raises(ActiveRecord::ReadOnlyRecord) { sem_notificacoes.destroy }
  end
end
