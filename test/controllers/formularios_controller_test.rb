require "test_helper"

class FormulariosControllerTest < ActionDispatch::IntegrationTest
  test "exige login" do
    get formularios_path

    assert_redirected_to new_user_session_path
  end

  test "Formulários lista o que a pessoa consulta, com os registros que ela vê; nova só para quem registra" do
    { operador: [ true, 2 ], admin: [ true, 3 ], consultor: [ false, 2 ], laboratorista: [ true, 1 ] }.each do |papel, (registra, total)|
      sign_in users(papel)
      get formularios_path

      assert_response :success
      assert_includes response.body, "Seguimento de TB"
      assert_includes response.body, total == 1 ? "1 registro" : "#{total} registros", papel
      assert_includes response.body, formulario_avaliacoes_clinicas_path("seguimento_tb")
      assert_equal registra, response.body.include?(new_formulario_avaliacao_clinica_path("seguimento_tb")), papel
    end
  end

  test "sem liberação, nenhum formulário aparece (nem no menu)" do
    sign_in users(:sem_acesso)
    get formularios_path

    assert_response :success
    assert_not_includes response.body, "Seguimento de TB"
    assert_includes response.body, "Nenhum formulário liberado"
  end

  test "o menu lateral marca a seção atual" do
    sign_in users(:consultor)
    get formularios_path

    assert_select "nav a[aria-current='page']", text: "Formulários"
    assert_select "nav a", text: "Visão geral"
  end
end
