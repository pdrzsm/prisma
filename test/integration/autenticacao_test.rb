require "test_helper"

class AutenticacaoTest < ActionDispatch::IntegrationTest
  test "entra com username ou com CPF formatado" do
    user = users(:operador)

    entrar user.username.upcase
    assert_redirected_to root_path

    delete destroy_user_session_path
    entrar formatar_cpf(user.cpf)
    assert_redirected_to root_path
  end

  test "mesma resposta para usuário inexistente, senha errada e conta bloqueada" do
    entrar "usuario_inexistente"
    inexistente = [ response.status, flash[:alert] ]
    assert_equal "Usuário, CPF ou senha inválidos.", flash[:alert]

    entrar users(:operador).username, "senha-errada-123"
    assert_equal inexistente, [ response.status, flash[:alert] ]

    users(:consultor).lock_access!
    entrar users(:consultor).username
    assert_equal inexistente, [ response.status, flash[:alert] ]
  end

  test "bloqueia após 5 senhas erradas e libera após 15 minutos" do
    user = users(:operador)

    5.times { entrar user.username, "senha-errada-123" }
    assert user.reload.access_locked?

    entrar user.username
    assert_response :unprocessable_content

    travel 16.minutes do
      entrar user.username
      assert_redirected_to root_path
    end
  end

  test "sessão expira após 30 minutos sem uso e avisa ao voltar ao login" do
    sign_in users(:operador)
    get root_path
    assert_response :success

    # O Devise encerra a sessão e volta para a página pedida, que exige login
    travel 31.minutes do
      get root_path
      follow_redirect!
      assert_redirected_to new_user_session_path
      follow_redirect!
      assert_includes response.body, "Sua sessão expirou. Entre novamente para continuar."
    end
  end

  # Regressão: saía para a raiz, que exige login, e o aviso de saída se perdia
  test "sair encerra a sessão, vai direto para o login e confirma em português" do
    entrar users(:operador).username
    delete destroy_user_session_path
    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_includes response.body, "Você saiu do sistema."

    get root_path
    assert_redirected_to new_user_session_path
  end

  test "conta bloqueada enquanto logada perde o acesso na requisição seguinte" do
    user = users(:operador)
    entrar user.username
    get root_path
    assert_response :success

    user.lock_access!
    get root_path
    assert_redirected_to new_user_session_path
  end

  test "tela de login não oferece 'lembrar de mim'" do
    get new_user_session_path

    assert_response :success
    assert_not_includes response.body, "remember_me"
  end

  private

  def entrar(login, senha = SENHA_DE_TESTE)
    post user_session_path, params: { user: { login:, password: senha } }
  end
end
