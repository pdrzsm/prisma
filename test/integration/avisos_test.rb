require "test_helper"

# Avisos do sistema (shared/_avisos): pop-ups com a marca, sem JavaScript
class AvisosTest < ActionDispatch::IntegrationTest
  test "login com sucesso mostra o aviso que some sozinho" do
    post user_session_path, params: { user: { login: users(:operador).username, password: SENHA_DE_TESTE } }
    follow_redirect!

    assert_select "dialog.aviso.aviso-ok[open]", 1 do
      assert_select "p[role='status']", text: /Login efetuado com sucesso\./
      assert_select "svg[aria-label='Prisma']", 2 # símbolo e nome (PRIƧM∀)
      assert_select "form[method='dialog'] button[aria-label='Fechar aviso']", 1
      assert_select ".aviso-tempo", 1
    end
  end

  test "erro fica até ser fechado e é anunciado como alerta" do
    post user_session_path, params: { user: { login: "ninguem", password: "senha-errada-123" } }

    assert_select "dialog.aviso.aviso-erro[open]", 1 do
      assert_select "p[role='alert']", text: /Usuário, CPF ou senha inválidos\./
      assert_select ".aviso-tempo", 0
    end
  end

  test "sem aviso, nada é desenhado" do
    get new_user_session_path

    assert_select "dialog.aviso", 0
  end

  test "permissão negada vem como aviso de erro" do
    sign_in users(:consultor)
    # Consultor tentando gravar: o aviso de permissão volta pelo flash
    post formulario_avaliacoes_clinicas_path("seguimento_tb"), params: { avaliacao_clinica: { dados_formulario: {} } }
    follow_redirect!

    assert_select "dialog.aviso-erro p[role='alert']", text: /Você não tem permissão/
  end
end
