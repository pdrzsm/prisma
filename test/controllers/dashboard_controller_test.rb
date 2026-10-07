require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "exige login" do
    get root_path

    assert_redirected_to new_user_session_path
  end

  test "todos veem a visão geral, com os totais só do que podem ver" do
    { operador: 2, admin: 3, consultor: 2, laboratorista: 1, sem_acesso: 0 }.each do |papel, total|
      sign_in users(papel)
      get root_path

      assert_response :success
      assert_select "nav a[aria-current='page']", text: "Visão geral"
      assert_select "a[href='#{formularios_path}']", minimum: 1
      assert_select "p.text-3xl", text: total.to_s
    end
  end

  test "a visão geral mostra a cada um o seu acesso" do
    {
      admin: /conta\s+admin\s*: administra o sistema/,
      operador: /CRF - Ambulatório\s*:\s+Seguimento de TB \(registra\)/,
      consultor: /CRF - Ambulatório\s*:\s+Seguimento de TB \(só consulta\)/,
      sem_acesso: /ainda não tem nenhum acesso liberado/
    }.each do |papel, acesso|
      sign_in users(papel)
      get root_path

      assert_match acesso, response.body.gsub(/<[^>]+>/, " ").squish, papel
      [ "O que é o Prisma", "Como funciona", "Quem pode o quê", "Segurança e privacidade" ].each do |titulo|
        assert_select "h2", text: titulo
      end
    end
  end

  test "os números de login e sessão vêm da configuração do Devise" do
    sign_in users(:operador)
    get root_path

    assert_select "li", text: /Depois de #{Devise.maximum_attempts} senhas erradas.*#{Devise.unlock_in.in_minutes.to_i} minutos/
    assert_select "li", text: /expira após #{Devise.timeout_in.in_minutes.to_i} minutos sem uso/
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
