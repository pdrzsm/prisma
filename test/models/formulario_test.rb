require "test_helper"

# O formulário (a identidade: chave e versões). O conteúdo de cada versão é
# testado em DefinicaoDeFormularioTest.
class FormularioTest < ActiveSupport::TestCase
  test "chave nova vem do título, sem acentos, sem repetir e sem nome reservado" do
    assert_equal "avaliacao_nutricional", Formulario.chave_para("Avaliação  Nutricional!")
    assert_equal "acompanhamento_2", Formulario.chave_para("Acompanhamento")
    assert_equal "formulario", Formulario.chave_para("123 ---")
    assert_equal "formulario", Formulario.chave_para("‮")
    assert_equal "new_2", Formulario.chave_para("New")
    assert_equal "triagem", Formulario.chave_para("2ª Triagem")
    assert_operator Formulario.chave_para("x" * 300).length, :<=, 64
  end

  test "chave com formato inválido ou reservada é recusada, e não muda depois" do
    [ "Maiuscula", "1comeca", "com-hifen", "", "a" * 65, "new", "edit" ].each do |chave|
      assert_not Formulario.new(chave:, instituicao: instituicoes(:centro)).valid?, chave
    end
    assert_raises(ActiveRecord::ReadonlyAttributeError) { formularios(:acompanhamento).chave = "outra" }
  end

  test "o banco também recusa chave fora do formato" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Formulario.insert!({ chave: "Fora_Do_Formato", instituicao_id: instituicoes(:centro).id, created_at: Time.current, updated_at: Time.current })
    end
  end

  test "só os publicados contam para quem preenche" do
    rascunho = Formulario.create!(chave: "so_rascunho", instituicao: instituicoes(:centro))
    rascunho.versoes.create!(numero: 1, estrutura: estrutura_de_formulario)

    assert_equal [ "acompanhamento" ], Formulario.chaves
    assert_equal [ formularios(:acompanhamento) ], Formulario.todos
    assert_raises(ActiveRecord::RecordNotFound) { Formulario.publicado!("so_rascunho") }
    assert_raises(ActiveRecord::RecordNotFound) { Formulario.publicado!("nao_existe") }
    assert_equal formularios(:acompanhamento), Formulario.publicado!("acompanhamento")
    assert_equal "Formulário de teste", rascunho.titulo
  end

  test "todos em ordem de título, sem diferenciar acentos" do
    publicar_formulario("zebra", estrutura_de_formulario(titulo: "Zebra"))
    publicar_formulario("abacaxi", estrutura_de_formulario(titulo: "Ábaco"))

    assert_equal [ "Ábaco", "Acompanhamento de teste", "Zebra" ], Formulario.todos.map(&:titulo)
  end

  test "com notificações nunca é excluído, publicado ou não, e o banco também não deixa" do
    acompanhamento = formularios(:acompanhamento)

    assert_not acompanhamento.excluivel?
    assert_no_difference [ -> { Formulario.count }, -> { VersaoFormulario.count }, -> { FormularioHabilitado.count } ] do
      assert_not acompanhamento.destroy
    end
    assert_includes acompanhamento.errors.full_messages, "Formulário com notificações não é excluído: o registro clínico é preservado"
    # Sem passar pelo model, a chave estrangeira das notificações recusa
    assert_raises(ActiveRecord::InvalidForeignKey) { Formulario.where(chave: "acompanhamento").delete_all }
  end

  test "o que nunca foi publicado sai com o rascunho" do
    rascunho = Formulario.create!(chave: "descartavel", instituicao: instituicoes(:centro))
    rascunho.versoes.create!(numero: 1, estrutura: estrutura_de_formulario)

    assert rascunho.excluivel?
    assert_difference -> { VersaoFormulario.count }, -1 do
      assert rascunho.destroy
    end
  end

  test "publicado que nunca teve notificação sai inteiro: versões, habilitações e liberações, com o autor na auditoria" do
    formulario = publicar_formulario("sem_uso")
    formulario.versoes.create!(numero: 2, estrutura: estrutura_de_formulario) # rascunho da versão 2
    setores(:ambulatorio).formularios_habilitados.create!(formulario: "sem_uso")
    users(:operador).liberacoes_formulario.create!(setor: setores(:ambulatorio), formulario: "sem_uso", papel: "registra")

    assert formulario.excluivel?
    PaperTrail.request.whodunnit = users(:admin).id.to_s
    assert_difference [ -> { Formulario.count }, -> { FormularioHabilitado.count }, -> { LiberacaoFormulario.count } ], -1 do
      assert_difference -> { VersaoFormulario.count }, -2 do
        assert formulario.destroy
      end
    end

    # Cada coisa que saiu ficou na auditoria, com quem excluiu
    %w[Formulario VersaoFormulario FormularioHabilitado LiberacaoFormulario].each do |tipo|
      exclusoes = PaperTrail::Version.where(item_type: tipo, event: "destroy")
      assert_operator exclusoes.count, :>=, 1, tipo
      assert_equal [ users(:admin).id.to_s ], exclusoes.pluck(:whodunnit).uniq, tipo
    end
  end

  test "uma versão publicada não sai sozinha, nem a de um formulário sem notificações" do
    formulario = publicar_formulario("sem_uso")

    assert_raises(ActiveRecord::ReadOnlyRecord) { formulario.versao_publicada.destroy }
    assert_raises(ActiveRecord::ReadOnlyRecord) { versoes_formulario(:acompanhamento_v1).destroy }
    assert_equal 1, formulario.reload.versoes.count
  end

  test "a versão publicada precisa ser deste formulário e estar publicada" do
    outro = publicar_formulario("outro")
    acompanhamento = formularios(:acompanhamento)

    acompanhamento.versao_publicada = outro.versao_publicada
    assert_not acompanhamento.valid?

    rascunho = acompanhamento.versoes.create!(numero: 2, estrutura: estrutura_de_formulario)
    acompanhamento.versao_publicada = rascunho
    assert_not acompanhamento.valid?
  end

  test "a chave das notificações, liberações e habilitações aponta para um formulário que existe" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      AvaliacaoClinica.where(id: avaliacoes_clinicas(:one).id).update_all(formulario: "nao_existe")
    end
    assert_raises(ActiveRecord::InvalidForeignKey) { formularios(:acompanhamento).update_column(:versao_publicada_id, 0) }
  end
end
