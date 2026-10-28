require "test_helper"

# O RBAC: cada nível de liberação é obrigatório, e nada é herdado (ver Permissoes)
class PermissoesTest < ActiveSupport::TestCase
  FORMULARIO = "acompanhamento".freeze

  setup do
    @ambulatorio = setores(:ambulatorio)
    @laboratorio = setores(:laboratorio)
  end

  test "com os três níveis, o papel é o da liberação do formulário" do
    assert_equal "registra", papel(:operador, @ambulatorio)
    assert_equal "consulta", papel(:consultor, @ambulatorio)
    assert permissoes(:operador).registra?(@ambulatorio.id, FORMULARIO)
    assert permissoes(:consultor).consulta?(@ambulatorio.id, FORMULARIO)
    assert_not permissoes(:consultor).registra?(@ambulatorio.id, FORMULARIO)
  end

  test "liberação num setor não vale em outro setor" do
    assert_nil papel(:operador, @laboratorio)
    assert_nil papel(:laboratorista, @ambulatorio)
    assert_equal "registra", papel(:laboratorista, @laboratorio)
  end

  test "sem a liberação da instituição, setor e formulário não valem" do
    liberacoes_instituicao(:operador_centro).destroy!

    assert_nil papel(:operador, @ambulatorio)
    assert_empty permissoes(:operador).setores_que_consultam(FORMULARIO)
  end

  test "sem a liberação do setor, o formulário não vale" do
    liberacoes_setor(:operador_ambulatorio).destroy!

    assert_nil papel(:operador, @ambulatorio)
  end

  test "sem a liberação do formulário, instituição e setor não dão acesso a nada" do
    liberacoes_formulario(:operador_acompanhamento).destroy!

    assert_nil papel(:operador, @ambulatorio)
    assert_not permissoes(:operador).consulta_o_formulario?(FORMULARIO)
  end

  test "formulário desabilitado no setor não vale, mesmo com as três liberações" do
    formularios_habilitados(:acompanhamento_ambulatorio).delete

    assert_nil papel(:operador, @ambulatorio)
  end

  test "liberação de um formulário que nunca foi publicado não vale" do
    # Direto no banco: as validações não deixam habilitar nem liberar um formulário sem versão publicada
    rascunho = Formulario.create!(chave: "rascunho", instituicao: instituicoes(:centro))
    rascunho.versoes.create!(numero: 1, estrutura: estrutura_de_formulario)
    FormularioHabilitado.insert!({ setor_id: @ambulatorio.id, formulario: "rascunho", created_at: Time.current, updated_at: Time.current })
    LiberacaoFormulario.insert!({ user_id: users(:operador).id, setor_id: @ambulatorio.id, formulario: "rascunho",
                                  papel: "registra", created_at: Time.current, updated_at: Time.current })

    assert_nil papel(:operador, @ambulatorio, "rascunho")
    assert_nil Permissoes.new(users(:admin)).papel(@ambulatorio.id, "rascunho")
    assert_not permissoes(:operador).consulta_o_formulario?("rascunho")
    assert_empty permissoes(:operador).escopo_de_avaliacoes(AvaliacaoClinica).where(formulario: "rascunho")
  end

  test "o banco não aceita liberação nem habilitação de formulário que não existe" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      FormularioHabilitado.insert!({ setor_id: @ambulatorio.id, formulario: "nao_existe", created_at: Time.current, updated_at: Time.current })
    end
    # A chave é sempre minúscula: o banco recusa mesmo o que a comparação sem diferenciar maiúsculas aceitaria
    assert_raises(ActiveRecord::StatementInvalid) do
      LiberacaoFormulario.insert!({ user_id: users(:operador).id, setor_id: @ambulatorio.id, formulario: "ACOMPANHAMENTO",
                                    papel: "registra", created_at: Time.current, updated_at: Time.current })
    end
  end

  test "conta desativada não pode nada" do
    users(:operador).update!(ativo: false)

    assert_nil papel(:operador, @ambulatorio)
    assert_empty AvaliacaoClinica.then { |escopo| permissoes(:operador).escopo_de_avaliacoes(escopo) }
  end

  test "sem nenhuma liberação, nada" do
    assert_empty permissoes(:sem_acesso).acessos
    assert_empty permissoes(:sem_acesso).escopo_de_avaliacoes(AvaliacaoClinica)
    assert_not permissoes(:sem_acesso).consulta_o_formulario?(FORMULARIO)
  end

  test "o escopo traz só as notificações dos setores liberados" do
    assert_equal avaliacoes_clinicas(:one, :two).sort, permissoes(:operador).escopo_de_avaliacoes(AvaliacaoClinica).sort
    assert_equal [ avaliacoes_clinicas(:tres) ], permissoes(:laboratorista).escopo_de_avaliacoes(AvaliacaoClinica).to_a
  end

  test "o admin vê tudo e registra onde o formulário está habilitado" do
    admin = permissoes(:admin)

    assert_equal AvaliacaoClinica.count, admin.escopo_de_avaliacoes(AvaliacaoClinica).count
    assert admin.registra?(@ambulatorio.id, FORMULARIO)
    assert_equal [ @ambulatorio.id, @laboratorio.id ].sort, admin.setores_que_registram(FORMULARIO).sort

    formularios_habilitados(:acompanhamento_laboratorio).delete
    assert_equal "consulta", Permissoes.new(users(:admin)).papel(@laboratorio.id, FORMULARIO)
  end

  test "os formulários consultados são os que a pessoa vê em pelo menos um setor" do
    %i[admin operador consultor laboratorista].each do |nome|
      assert_equal [ FORMULARIO ], permissoes(nome).formularios_consultados.map(&:chave), nome
    end
    assert_empty permissoes(:sem_acesso).formularios_consultados

    liberacoes_formulario(:operador_acompanhamento).destroy!
    assert_empty permissoes(:operador).formularios_consultados
  end

  private

  def permissoes(nome)
    Permissoes.new(users(nome).reload)
  end

  def papel(nome, setor, formulario = FORMULARIO)
    permissoes(nome).papel(setor.id, formulario)
  end
end
