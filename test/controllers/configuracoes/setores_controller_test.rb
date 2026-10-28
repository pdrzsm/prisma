require "test_helper"

module Configuracoes
  class SetoresControllerTest < ActionDispatch::IntegrationTest
    test "operador e consultor não mexem em setores" do
      centro = instituicoes(:centro)

      %i[operador consultor].each do |papel|
        sign_in users(papel)

        get new_configuracoes_instituicao_setor_path(centro)
        assert_redirected_to root_path

        assert_no_difference -> { Setor.count } do
          post configuracoes_instituicao_setores_path(centro), params: { setor: { nome: "Invasor" } }
          delete configuracoes_instituicao_setor_path(centro, setores(:ambulatorio))
        end
      end
    end

    test "admin cadastra, edita e exclui um setor" do
      sign_in users(:admin)
      hospital = instituicoes(:hospital)

      # O mesmo nome de um setor de outra instituição é aceito
      post configuracoes_instituicao_setores_path(hospital), params: { setor: { nome: "Ambulatório" } }
      setor = hospital.setores.find_by!(nome: "Ambulatório")
      assert_redirected_to configuracoes_instituicoes_path(anchor: "instituicao_#{hospital.id}")
      assert_equal "Setor cadastrado.", flash[:notice]

      patch configuracoes_instituicao_setor_path(hospital, setor), params: { setor: { nome: "Enfermaria" } }
      assert_equal "Enfermaria", setor.reload.nome

      delete configuracoes_instituicao_setor_path(hospital, setor)
      assert_not Setor.exists?(setor.id)
      assert_equal "Setor excluído.", flash[:notice]
    end

    test "o Excluir fica na linha do Salvar e envia o formulário de exclusão" do
      sign_in users(:admin)
      instituicao = instituicoes(:centro)
      setor = setores(:ambulatorio)
      get edit_configuracoes_instituicao_setor_path(instituicao, setor)

      # O botão está dentro do formulário de edição, mas aponta (form=) para o de exclusão
      assert_select "form[action='#{configuracoes_instituicao_setor_path(instituicao, setor)}'] button[form='excluir_setor']", text: "Excluir setor"
      assert_select "form#excluir_setor[hidden][action='#{configuracoes_instituicao_setor_path(instituicao, setor)}']" do
        assert_select "input[name='_method'][value='delete']"
      end
    end

    test "o setor abre num modal sobre a lista, com os formulários em interruptores" do
      sign_in users(:admin)
      centro = instituicoes(:centro)
      get edit_configuracoes_instituicao_setor_path(centro, setores(:ambulatorio))

      assert_select "div[inert] li#instituicao_#{centro.id}"
      assert_select "dialog.modal" do
        assert_select "h1", "Editar setor"
        assert_select "a[aria-label='Fechar'][href='#{configuracoes_instituicoes_path(anchor: "instituicao_#{centro.id}")}']"
        assert_select "label[for='setor_formulario_acompanhamento'] input[type=checkbox][role=switch]" \
                      "[name='setor[formularios][]'][value='acompanhamento'][aria-labelledby='setor_formulario_acompanhamento_titulo'][checked]"
      end
    end

    test "o admin habilita os formulários do setor, só os da instituição dele" do
      sign_in users(:admin)
      centro = instituicoes(:centro)
      post configuracoes_instituicao_setores_path(centro), params: { setor: { nome: "Enfermaria", formularios: [ "", "acompanhamento" ] } }
      assert_equal [ "acompanhamento" ], centro.setores.find_by!(nome: "Enfermaria").formularios

      # O acompanhamento é do centro: num setor do hospital, nem aparece nem entra
      hospital = instituicoes(:hospital)
      get new_configuracoes_instituicao_setor_path(hospital)
      assert_select "input[value='acompanhamento']", 0
      post configuracoes_instituicao_setores_path(hospital), params: { setor: { nome: "Enfermaria", formularios: [ "", "acompanhamento" ] } }
      assert_empty hospital.setores.find_by!(nome: "Enfermaria").formularios
    end

    test "desabilitar um formulário tira as liberações dele no setor" do
      sign_in users(:admin)
      laboratorio = setores(:laboratorio)
      patch configuracoes_instituicao_setor_path(instituicoes(:centro), laboratorio), params: { setor: { nome: "Laboratório", formularios: [ "" ] } }

      # O Laboratório tem a notificação "tres": o formulário não sai
      assert_response :unprocessable_content
      assert_includes response.body, "tem notificações neste setor e não pode ser desabilitado"
      assert_equal [ "acompanhamento" ], laboratorio.reload.formularios

      sem_notificacoes = instituicoes(:centro).setores.create!(nome: "Vazio")
      sem_notificacoes.habilitar_formularios([ "acompanhamento" ])
      users(:operador).liberacoes_setor.create!(setor: sem_notificacoes)
      users(:operador).liberacoes_formulario.create!(setor: sem_notificacoes, formulario: "acompanhamento", papel: "registra")

      patch configuracoes_instituicao_setor_path(instituicoes(:centro), sem_notificacoes), params: { setor: { nome: "Vazio", formularios: [ "" ] } }
      assert_empty sem_notificacoes.reload.formularios
      assert_not users(:operador).liberacoes_formulario.exists?(setor: sem_notificacoes)
    end

    test "setor com pacientes não é excluído" do
      sign_in users(:admin)
      delete configuracoes_instituicao_setor_path(instituicoes(:centro), setores(:ambulatorio))

      assert_redirected_to edit_configuracoes_instituicao_setor_path(instituicoes(:centro), setores(:ambulatorio))
      assert_match "Não é possível excluir enquanto houver", flash[:alert]
      assert Setor.exists?(setores(:ambulatorio).id)
    end

    test "setor de outra instituição na URL dá 404" do
      sign_in users(:admin)
      get edit_configuracoes_instituicao_setor_path(instituicoes(:hospital), setores(:ambulatorio))

      assert_response :not_found
    end

    test "nome repetido na mesma instituição volta com erro" do
      sign_in users(:admin)
      post configuracoes_instituicao_setores_path(instituicoes(:centro)), params: { setor: { nome: "laboratório" } }

      assert_response :unprocessable_content
      assert_select "#setor_nome_erros", text: "já está em uso"
    end

    test "o formulário não muda o setor de instituição" do
      sign_in users(:admin)
      ambulatorio = setores(:ambulatorio)
      patch configuracoes_instituicao_setor_path(instituicoes(:centro), ambulatorio),
            params: { setor: { nome: "Ambulatório", instituicao_id: instituicoes(:hospital).id } }

      assert_equal instituicoes(:centro), ambulatorio.reload.instituicao
    end
  end
end
