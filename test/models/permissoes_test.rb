require "test_helper"

# O RBAC: cada nível de liberação é obrigatório, e nada é herdado (ver Permissoes)
class PermissoesTest < ActiveSupport::TestCase
  TB = "seguimento_tb".freeze

  setup do
    @ambulatorio = setores(:ambulatorio)
    @laboratorio = setores(:laboratorio)
  end

  test "com os três níveis, o papel é o da liberação do formulário" do
    assert_equal "registra", papel(:operador, @ambulatorio)
    assert_equal "consulta", papel(:consultor, @ambulatorio)
    assert permissoes(:operador).registra?(@ambulatorio.id, TB)
    assert permissoes(:consultor).consulta?(@ambulatorio.id, TB)
    assert_not permissoes(:consultor).registra?(@ambulatorio.id, TB)
  end

  test "liberação num setor não vale em outro setor" do
    assert_nil papel(:operador, @laboratorio)
    assert_nil papel(:laboratorista, @ambulatorio)
    assert_equal "registra", papel(:laboratorista, @laboratorio)
  end

  test "sem a liberação da instituição, setor e formulário não valem" do
    liberacoes_instituicao(:operador_centro).destroy!

    assert_nil papel(:operador, @ambulatorio)
    assert_empty permissoes(:operador).setores_que_consultam(TB)
  end

  test "sem a liberação do setor, o formulário não vale" do
    liberacoes_setor(:operador_ambulatorio).destroy!

    assert_nil papel(:operador, @ambulatorio)
  end

  test "sem a liberação do formulário, instituição e setor não dão acesso a nada" do
    liberacoes_formulario(:operador_tb).destroy!

    assert_nil papel(:operador, @ambulatorio)
    assert_not permissoes(:operador).consulta_o_formulario?(TB)
  end

  test "formulário desabilitado no setor não vale, mesmo com as três liberações" do
    formularios_habilitados(:tb_ambulatorio).delete

    assert_nil papel(:operador, @ambulatorio)
  end

  test "liberação de um formulário que não existe mais no YAML não vale" do
    FormularioHabilitado.insert!({ setor_id: @ambulatorio.id, formulario: "antigo", created_at: Time.current, updated_at: Time.current })
    LiberacaoFormulario.insert!({ user_id: users(:operador).id, setor_id: @ambulatorio.id, formulario: "antigo",
                                  papel: "registra", created_at: Time.current, updated_at: Time.current })

    assert_nil papel(:operador, @ambulatorio, "antigo")
  end

  test "conta desativada não pode nada" do
    users(:operador).update!(ativo: false)

    assert_nil papel(:operador, @ambulatorio)
    assert_empty AvaliacaoClinica.then { |escopo| permissoes(:operador).escopo_de_avaliacoes(escopo) }
  end

  test "sem nenhuma liberação, nada" do
    assert_empty permissoes(:sem_acesso).acessos
    assert_empty permissoes(:sem_acesso).escopo_de_avaliacoes(AvaliacaoClinica)
    assert_not permissoes(:sem_acesso).consulta_o_formulario?(TB)
  end

  test "o escopo traz só as notificações dos setores liberados" do
    assert_equal avaliacoes_clinicas(:one, :two).sort, permissoes(:operador).escopo_de_avaliacoes(AvaliacaoClinica).sort
    assert_equal [ avaliacoes_clinicas(:tres) ], permissoes(:laboratorista).escopo_de_avaliacoes(AvaliacaoClinica).to_a
  end

  test "o admin vê tudo e registra onde o formulário está habilitado" do
    admin = permissoes(:admin)

    assert_equal AvaliacaoClinica.count, admin.escopo_de_avaliacoes(AvaliacaoClinica).count
    assert admin.registra?(@ambulatorio.id, TB)
    assert_equal [ @ambulatorio.id, @laboratorio.id ].sort, admin.setores_que_registram(TB).sort

    formularios_habilitados(:tb_laboratorio).delete
    assert_equal "consulta", Permissoes.new(users(:admin)).papel(@laboratorio.id, TB)
  end

  private

  def permissoes(nome)
    Permissoes.new(users(nome).reload)
  end

  def papel(nome, setor, formulario = TB)
    permissoes(nome).papel(setor.id, formulario)
  end
end
