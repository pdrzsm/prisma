require "test_helper"

module Configuracoes
  class UsuariosControllerTest < ActionDispatch::IntegrationTest
    NOVA_SENHA = "senha-temporaria-123".freeze

    test "só o admin entra em Usuários, nem pela URL os outros" do
      %i[operador consultor laboratorista sem_acesso].each do |papel|
        sign_in users(papel)

        get configuracoes_usuarios_path
        assert_redirected_to root_path, papel
        assert_no_difference -> { User.count } do
          post configuracoes_usuarios_path, params: { usuario: dados_novos }
        end
        patch configuracoes_usuario_path(users(:operador)), params: { usuario: { nome: "Trocado" } }
        assert_equal "Operador de Teste", users(:operador).reload.nome
      end
    end

    test "o admin lista todos, com a situação de cada um" do
      sign_in users(:admin)
      get configuracoes_usuarios_path

      assert_response :success
      assert_select "tbody tr", User.count
      assert_select "nav[aria-label='Seções do sistema'] a[aria-current='page']", text: /Usuários/
    end

    test "conta nova é sempre de usuário comum, com senha temporária, e vai para as liberações" do
      sign_in users(:admin)

      assert_difference -> { User.count }, 1 do
        post configuracoes_usuarios_path, params: { usuario: dados_novos.merge(role: "admin", ativo: "0", deve_trocar_senha: "0") }
      end
      novo = User.find_by!(username: "pessoa.nova")
      assert novo.usuario?, "o papel nunca vem do formulário"
      assert novo.ativo?
      assert novo.deve_trocar_senha?
      assert_redirected_to edit_configuracoes_usuario_liberacoes_path(novo)
      assert_empty novo.permissoes.acessos, "começa sem acesso a nada"
    end

    test "erros voltam ao lado do campo" do
      sign_in users(:admin)
      post configuracoes_usuarios_path, params: { usuario: dados_novos.merge(username: "operador_teste", password_confirmation: "outra") }

      assert_response :unprocessable_content
      assert_select "#usuario_username_erros", text: "já está em uso"
      assert_select "#usuario_password_confirmation_erros"
    end

    test "o admin desativa e reativa um usuário; o papel não muda pela edição" do
      sign_in users(:admin)
      operador = users(:operador)

      patch configuracoes_usuario_path(operador), params: { usuario: { ativo: "0", role: "admin" } }
      assert_not operador.reload.ativo?
      assert operador.usuario?

      patch configuracoes_usuario_path(operador), params: { usuario: { ativo: "1" } }
      assert operador.reload.ativo?
    end

    test "a edição abre num modal sobre a lista, com a conta ativa num interruptor" do
      sign_in users(:admin)
      operador = users(:operador)
      get edit_configuracoes_usuario_path(operador)

      assert_select "div[inert] tbody tr", User.count
      assert_select "dialog.modal" do
        assert_select "h1", "Editar usuário"
        assert_select "label[for='usuario_ativo'] input[type=checkbox][role=switch][name='usuario[ativo]']" \
                      "[aria-labelledby='usuario_ativo_titulo'][aria-describedby='usuario_ativo_subtitulo'][checked]"
        # O valor "0" vai mesmo com o interruptor desligado
        assert_select "input[type=hidden][name='usuario[ativo]'][value='0']"
        assert_select "a[href='#{edit_configuracoes_usuario_liberacoes_path(operador)}']", text: /Liberações/
        assert_select "a[href='#{edit_configuracoes_usuario_senha_path(operador)}']", text: /Senha temporária/
      end

      get edit_configuracoes_usuario_senha_path(operador)
      assert_select "div[inert] tbody tr", User.count
      assert_select "dialog.modal form[action='#{configuracoes_usuario_senha_path(operador)}'] #usuario_password"
    end

    test "a conta admin não se desativa, nem enviando o campo à mão" do
      sign_in users(:admin)
      patch configuracoes_usuario_path(users(:admin)), params: { usuario: { nome: "Admin Renomeado", ativo: "0" } }

      assert users(:admin).reload.ativo?
      assert_equal "Admin Renomeado", users(:admin).nome
      get edit_configuracoes_usuario_path(users(:admin))
      assert_select "input[name='usuario[ativo]']", 0
    end

    test "não há rota para excluir usuário" do
      sign_in users(:admin)

      assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path(configuracoes_usuario_path(users(:operador)), method: :delete) }
    end

    test "cada alteração vai para a auditoria, sem o hash da senha" do
      sign_in users(:admin)
      post configuracoes_usuarios_path, params: { usuario: dados_novos }
      versao = User.find_by!(username: "pessoa.nova").versions.last

      assert_equal users(:admin).id.to_s, versao.whodunnit
      assert_not_includes versao.object_changes.to_s, "encrypted_password"
    end

    private

    def dados_novos
      { nome: "Pessoa Nova", username: "pessoa.nova", cpf: Cpf.gerar, password: NOVA_SENHA, password_confirmation: NOVA_SENHA }
    end
  end
end
