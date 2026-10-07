require "test_helper"

# Senha temporária, troca obrigatória e conta desativada, de ponta a ponta
class ContasTest < ActionDispatch::IntegrationTest
  TEMPORARIA = "senha-temporaria-123".freeze
  NOVA = "minha-senha-nova-456".freeze

  test "com senha temporária, nenhuma tela abre antes da troca (o logout continua)" do
    users(:operador).update!(deve_trocar_senha: true)
    sign_in users(:operador)

    [ root_path, formularios_path, formulario_avaliacoes_clinicas_path("seguimento_tb") ].each do |caminho|
      get caminho
      assert_redirected_to edit_senha_path, caminho
    end
    get edit_senha_path
    assert_response :success

    delete destroy_user_session_path
    assert_redirected_to new_user_session_path
  end

  test "a troca exige a senha atual, uma nova diferente e não aceita a nova em branco" do
    users(:operador).update!(deve_trocar_senha: true)
    sign_in users(:operador)

    trocar(atual: "errada-errada-1", nova: NOVA)
    assert_response :unprocessable_content
    assert_select "#usuario_current_password_erros", text: "não confere"

    trocar(atual: SENHA_DE_TESTE, nova: "")
    assert_response :unprocessable_content
    assert users(:operador).reload.deve_trocar_senha?, "nova em branco não apaga a obrigação"

    trocar(atual: SENHA_DE_TESTE, nova: SENHA_DE_TESTE)
    assert_response :unprocessable_content
    assert_select "#usuario_password_erros", text: "precisa ser diferente da senha atual"

    trocar(atual: SENHA_DE_TESTE, nova: NOVA, confirmacao: "outra-coisa-789")
    assert_response :unprocessable_content
    assert users(:operador).reload.deve_trocar_senha?
  end

  test "trocar a senha libera o sistema e mantém a sessão" do
    users(:operador).update!(deve_trocar_senha: true)
    sign_in users(:operador)

    trocar(atual: SENHA_DE_TESTE, nova: NOVA)
    assert_redirected_to root_path
    assert_not users(:operador).reload.deve_trocar_senha?
    assert users(:operador).valid_password?(NOVA)

    get formularios_path
    assert_response :success
  end

  test "a troca é sempre da própria senha" do
    sign_in users(:operador)
    patch senha_path, params: { id: users(:consultor).id, usuario: { current_password: SENHA_DE_TESTE, password: NOVA, password_confirmation: NOVA } }

    assert users(:operador).reload.valid_password?(NOVA)
    assert users(:consultor).reload.valid_password?(SENHA_DE_TESTE)
  end

  test "senha temporária do admin: obriga a troca e derruba a sessão aberta" do
    operador = users(:operador)
    # Sessão do operador por login de verdade (o sign_in de teste vale para a
    # próxima requisição de qualquer sessão e se misturaria com o do admin)
    sessao_do_operador = open_session
    sessao_do_operador.post user_session_path, params: { user: { login: operador.username, password: SENHA_DE_TESTE } }
    sessao_do_operador.get root_path
    sessao_do_operador.assert_response :success

    sign_in users(:admin)
    patch configuracoes_usuario_senha_path(operador), params: { usuario: { password: TEMPORARIA, password_confirmation: TEMPORARIA } }
    assert_redirected_to edit_configuracoes_usuario_path(operador)
    operador.reload
    assert operador.deve_trocar_senha?
    assert operador.valid_password?(TEMPORARIA)

    # A senha mudou: a sessão que estava aberta não vale mais
    sessao_do_operador.get root_path
    sessao_do_operador.assert_redirected_to new_user_session_path

    # Entrando com a temporária, cai direto na troca
    sessao_do_operador.post user_session_path, params: { user: { login: operador.username, password: TEMPORARIA } }
    sessao_do_operador.follow_redirect!
    sessao_do_operador.assert_redirected_to edit_senha_path
  end

  test "senha temporária desbloqueia a conta bloqueada" do
    users(:operador).lock_access!
    sign_in users(:admin)
    patch configuracoes_usuario_senha_path(users(:operador)), params: { usuario: { password: TEMPORARIA, password_confirmation: TEMPORARIA } }

    assert_not users(:operador).reload.access_locked?
  end

  test "senha temporária: só o admin define, e não para a conta admin" do
    sign_in users(:consultor)
    patch configuracoes_usuario_senha_path(users(:operador)), params: { usuario: { password: TEMPORARIA, password_confirmation: TEMPORARIA } }
    assert_redirected_to root_path
    assert users(:operador).reload.valid_password?(SENHA_DE_TESTE)

    sign_in users(:admin)
    get edit_configuracoes_usuario_senha_path(users(:admin))
    assert_redirected_to root_path
  end

  test "conta desativada não entra, e a sessão aberta cai na próxima ação" do
    operador = users(:operador)
    sign_in operador
    get root_path
    assert_response :success

    operador.update!(ativo: false)
    get root_path
    assert_redirected_to new_user_session_path

    post user_session_path, params: { user: { login: operador.username, password: SENHA_DE_TESTE } }
    assert_redirected_to new_user_session_path
    assert_equal "Conta desativada. Fale com a administração do sistema.", flash[:alert]
  end

  private

  def trocar(atual:, nova:, confirmacao: nova)
    patch senha_path, params: { usuario: { current_password: atual, password: nova, password_confirmation: confirmacao } }
  end
end
