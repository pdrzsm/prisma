require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "exige login" do
    get root_path

    assert_redirected_to new_user_session_path
  end

  test "todos os papéis veem o painel com os totais reais e o acesso aos formulários" do
    %i[operador admin consultor].each do |papel|
      sign_in users(papel)
      get root_path

      assert_response :success
      assert_select "nav a[aria-current='page']", text: "Visão geral"
      assert_select "a[href='#{formularios_path}']", minimum: 1
      assert_select "p.text-3xl", text: AvaliacaoClinica.count.to_s
    end
  end

  test "painel não mostra o CPF de quem está logado" do
    user = users(:operador)
    sign_in user
    get root_path

    assert_not_includes response.body, user.cpf
  end

  test "páginas não ficam no cache do navegador e têm CSP restritiva" do
    sign_in users(:operador)
    get root_path

    assert_includes response.headers["Cache-Control"], "no-store"
    assert_includes response.headers["Content-Security-Policy"], "script-src 'self'"
    assert_includes response.headers["Content-Security-Policy"], "frame-ancestors 'none'"
  end
end
