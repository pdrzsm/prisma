require "test_helper"

# Transparência (LGPD, art. 6º, I e X, e art. 9º): quem digita sabe para que
# os dados são coletados e com qual base legal, e cada notificação guarda isso
class TransparenciaTest < ActionDispatch::IntegrationTest
  FORMULARIO = "seguimento_tb".freeze

  setup { @tb = Formulario.find(FORMULARIO) }

  test "o registro mostra a finalidade e a base legal antes de qualquer dado ser digitado" do
    sign_in users(:operador)
    get new_formulario_avaliacao_clinica_path(FORMULARIO)

    assert_response :success
    assert_finalidade @tb.finalidade, @tb.base_legal
    assert_operator response.body.index("Dados coletados para"), :<, response.body.index("paciente[prontuario_sah]")
  end

  test "a notificação mostra a finalidade gravada no registro, mesmo que o formulário mude depois" do
    sign_in users(:operador)
    avaliacao = avaliacoes_clinicas(:one)
    # Registrada com outra definição (direto no banco: o model não deixa mudar)
    AvaliacaoClinica.where(id: avaliacao.id)
                    .update_all(finalidade: "finalidade em vigor no registro", base_legal: "base legal em vigor no registro")

    [ formulario_avaliacao_clinica_path(FORMULARIO, avaliacao), edit_formulario_avaliacao_clinica_path(FORMULARIO, avaliacao) ].each do |pagina|
      get pagina
      assert_finalidade "finalidade em vigor no registro", "base legal em vigor no registro"
      assert_not_includes response.body, @tb.finalidade, pagina
    end
  end

  test "a finalidade vem sempre do formulário: enviada pela tela, é ignorada" do
    sign_in users(:operador)
    post formulario_avaliacoes_clinicas_path(FORMULARIO), params: {
      paciente: { prontuario_sah: "SAH-TRANSP", prontuario_aghuse: "", iniciais: "TRP" },
      avaliacao_clinica: { setor_id: setores(:ambulatorio).id, finalidade: "outra", base_legal: "outra",
                           dados_formulario: respostas_de_abertura }
    }

    avaliacao = AvaliacaoClinica.order(:id).last
    assert_redirected_to formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)
    assert_equal [ @tb.finalidade, @tb.base_legal ], [ avaliacao.finalidade, avaliacao.base_legal ]
  end

  test "a página de privacidade mostra a finalidade e a base legal de cada formulário" do
    sign_in users(:consultor)
    get privacidade_path

    assert_response :success
    Formulario.todos.each do |formulario|
      assert_select "li p", text: formulario.titulo
      assert_select "li p", text: "Dados coletados para #{formulario.finalidade.chomp('.')}."
      assert_select "li p", text: "Base legal: #{formulario.base_legal.chomp('.')}."
    end
    assert_includes response.body, "Lei 13.787/2018"
    assert_includes response.body, "Procure o encarregado de dados (DPO) da sua instituição."
  end

  test "com o encarregado configurado, a página mostra o contato dele" do
    Rails.configuration.x.encarregado = "Maria Souza · dpo@hospital.example"
    sign_in users(:operador)
    get privacidade_path

    assert_select "p", text: /Encarregado \(DPO\):\s+Maria Souza · dpo@hospital.example/
    assert_not_includes response.body, "Procure o encarregado"
  ensure
    Rails.configuration.x.encarregado = nil
  end

  test "o rodapé de todas as telas leva à página de privacidade" do
    sign_in users(:operador)

    [ root_path, formularios_path, formulario_avaliacoes_clinicas_path(FORMULARIO) ].each do |pagina|
      get pagina
      assert_select "footer a[href=?]", privacidade_path, { text: "Privacidade e proteção de dados" }, pagina
    end
  end

  private

  def assert_finalidade(finalidade, base_legal)
    assert_select "aside[aria-label='Finalidade da coleta']" do
      assert_select "p", text: "Dados coletados para #{finalidade.chomp('.')}."
      assert_select "p", text: "Base legal: #{base_legal.chomp('.')}."
      assert_select "a[href=?]", privacidade_path
    end
  end
end
