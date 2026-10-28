require "test_helper"

module Configuracoes
  class InstituicoesControllerTest < ActionDispatch::IntegrationTest
    test "exige login" do
      get configuracoes_instituicoes_path

      assert_redirected_to new_user_session_path
    end

    test "operador e consultor não entram, nem pela URL" do
      centro = instituicoes(:centro)
      hospital = instituicoes(:hospital)

      %i[operador consultor].each do |papel|
        sign_in users(papel)

        get configuracoes_instituicoes_path
        assert_redirected_to root_path
        assert_equal "Você não tem permissão para realizar esta ação.", flash[:alert]

        get edit_configuracoes_instituicao_path(centro)
        assert_redirected_to root_path

        assert_no_difference -> { Instituicao.count } do
          post configuracoes_instituicoes_path, params: { instituicao: { nome: "Invasora" } }
          delete configuracoes_instituicao_path(hospital)
        end
        patch configuracoes_instituicao_path(centro), params: { instituicao: { nome: "Trocada" } }
        assert_equal "Centro de Referência Fictício", centro.reload.nome
      end
    end

    test "o menu mostra Configurações só para o admin" do
      { admin: true, operador: false, consultor: false }.each do |papel, ve|
        sign_in users(papel)
        get root_path

        assert_select "aside nav[aria-label='Seções do sistema'] p", text: "Configurações", count: ve ? 1 : 0
      end
    end

    test "admin vê as instituições com os seus setores" do
      sign_in users(:admin)
      get configuracoes_instituicoes_path

      assert_response :success
      assert_select "nav[aria-label='Seções do sistema'] a[aria-current='page']", text: /Instituições e setores/
      assert_select "li#instituicao_#{instituicoes(:centro).id}" do
        assert_select "a[aria-label='Editar Centro de Referência Fictício']"
        assert_select "a[aria-label^='Editar setor']", 2
      end
      assert_select "li#instituicao_#{instituicoes(:hospital).id}", text: /0 setores/
    end

    test "admin cadastra, edita e exclui; a auditoria guarda o autor" do
      admin = users(:admin)
      sign_in admin

      post configuracoes_instituicoes_path, params: { instituicao: { nome: " Instituto  Novo ", sigla: "in" } }
      nova = Instituicao.find_by!(nome: "Instituto Novo")
      assert_redirected_to configuracoes_instituicoes_path(anchor: "instituicao_#{nova.id}")
      assert_equal "Instituição cadastrada.", flash[:notice]
      assert_equal "IN", nova.sigla

      patch configuracoes_instituicao_path(nova), params: { instituicao: { nome: "Instituto Renomeado" } }
      assert_equal "Instituto Renomeado", nova.reload.nome

      delete configuracoes_instituicao_path(nova)
      assert_redirected_to configuracoes_instituicoes_path
      assert_not Instituicao.exists?(nova.id)

      autores = PaperTrail::Version.where(item_type: "Instituicao", item_id: nova.id).pluck(:whodunnit)
      assert_equal [ admin.id.to_s ] * 3, autores
    end

    test "cadastrar e editar abrem num modal, com a lista inerte ao fundo" do
      sign_in users(:admin)
      centro = instituicoes(:centro)

      get configuracoes_instituicoes_path
      assert_select "[inert]", 0
      assert_select "dialog.modal", 0

      { new_configuracoes_instituicao_path => [ "Nova instituição", configuracoes_instituicoes_path ],
        edit_configuracoes_instituicao_path(centro) => [ "Editar instituição", configuracoes_instituicao_path(centro) ] }.each do |caminho, (titulo, acao)|
        get caminho

        assert_response :success
        assert_select "div[inert] li#instituicao_#{centro.id}", 1, caminho
        assert_select "dialog.modal[open][aria-modal='true'][aria-labelledby='modal_titulo'][autofocus]" do
          assert_select "h1#modal_titulo", titulo
          assert_select "a[aria-label='Fechar'][href^='#{configuracoes_instituicoes_path}']"
          assert_select "form[action='#{acao}'] #instituicao_nome"
        end
        assert_select "[inert] dialog.modal", 0, "o modal não pode ficar dentro da parte inerte"
      end
    end

    test "erros voltam no formulário, ao lado do campo" do
      sign_in users(:admin)
      post configuracoes_instituicoes_path, params: { instituicao: { nome: "hospital exemplo" } }

      assert_response :unprocessable_content
      # O modal volta aberto, com a lista ao fundo
      assert_select "div[inert] li[id^='instituicao_']"
      assert_select "dialog.modal #instituicao_nome[aria-invalid='true'][aria-describedby~='instituicao_nome_erros']"
      assert_select "#instituicao_nome_erros", text: "já está em uso"
      assert_select "dialog.aviso-erro", text: /Revise os campos destacados/
    end

    test "instituição sem setores tem o Excluir na linha do Salvar" do
      sign_in users(:admin)
      hospital = instituicoes(:hospital)
      get edit_configuracoes_instituicao_path(hospital)

      assert_select "button[form='excluir_instituicao']", text: "Excluir instituição"
      assert_select "form#excluir_instituicao[hidden] input[name='_method'][value='delete']"
    end

    test "instituição com setores não é excluída" do
      sign_in users(:admin)
      centro = instituicoes(:centro)

      get edit_configuracoes_instituicao_path(centro)
      assert_select "button", text: "Excluir instituição", count: 0
      assert_select "form#excluir_instituicao", 0
      assert_select "p", text: "Para excluir, remova antes os setores dela."

      delete configuracoes_instituicao_path(centro)
      assert_redirected_to edit_configuracoes_instituicao_path(centro)
      assert_equal "Não é possível excluir enquanto houver setores", flash[:alert]
      assert Instituicao.exists?(centro.id)
    end
  end
end
