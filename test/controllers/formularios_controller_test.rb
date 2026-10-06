require "test_helper"

class FormulariosControllerTest < ActionDispatch::IntegrationTest
  test "exige login" do
    get formularios_path

    assert_redirected_to new_user_session_path
  end

  test "aba Formulários lista o seguimento de TB; nova notificação só para quem registra" do
    { operador: true, admin: true, consultor: false }.each do |papel, registra|
      sign_in users(papel)
      get formularios_path

      assert_response :success
      assert_includes response.body, "Seguimento de TB"
      assert_includes response.body, "2 registros"
      assert_includes response.body, formulario_avaliacoes_clinicas_path("seguimento_tb")
      assert_equal registra, response.body.include?(new_formulario_avaliacao_clinica_path("seguimento_tb")), papel
    end
  end

  test "o menu lateral marca a seção atual" do
    sign_in users(:consultor)
    get formularios_path

    assert_select "nav a[aria-current='page']", text: "Formulários"
    assert_select "nav a", text: "Visão geral"
  end
end
