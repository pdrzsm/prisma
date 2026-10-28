require "application_system_test_case"

# No navegador, com o acompanhamento de teste das fixtures: a pergunta que
# depende de outra, o registro, a edição, os erros e o consultor.
class NotificacoesNavegadorTest < ApplicationSystemTestCase
  FORMULARIO = "acompanhamento".freeze

  test "a pergunta 10 só aparece para a forma disseminada" do
    sign_in users(:operador)
    visit new_formulario_avaliacao_clinica_path(FORMULARIO)

    assert_no_text "Se disseminada, onde?"
    assert_no_selector "#campo_locais_1", visible: true

    marcar "campo_forma_2" # Disseminada
    assert_text "Se disseminada, onde?"
    assert_selector "#campo_locais_1", visible: true

    marcar "campo_forma_1" # Localizada
    assert_no_text "Se disseminada, onde?"

    marcar "campo_forma_3" # Localizada + disseminada
    assert_text "Se disseminada, onde?"
  end

  test "operador registra uma notificação e depois atualiza o acompanhamento" do
    sign_in users(:operador)
    visit formulario_avaliacoes_clinicas_path(FORMULARIO)
    click_on "Nova notificação"

    fill_in "campo_prontuario_sah", with: "sah 7777"
    fill_in "campo_iniciais", with: "r. t. s."
    fill_in "campo_numero_registro", with: "7654321"
    marcar "campo_gestante_6", "campo_populacoes_especiais_0", "campo_recebe_beneficio_0", "campo_forma_2",
           "campo_locais_1"
    fill_in "campo_municipio_residencia", with: "Cidade Fictícia"
    click_on "Registrar notificação"

    # Espera a página nova antes de ler o texto. Sem isso, o Chrome às vezes
    # inspeciona a página antiga no meio da navegação e o teste falha à toa.
    assert_current_path %r{/avaliacoes/\d+\z}
    assert_text "Notificação registrada."
    assert_text "Notificação · RTS"
    assert_text "SAH7777"
    assert_text "Pele"
    assert_text "Em acompanhamento"

    click_on "Editar"
    assert_no_field "campo_iniciais" # identificação só para leitura
    marcar "campo_exame_mes_1_2"
    click_on "Salvar alterações"

    assert_current_path %r{/avaliacoes/\d+\z}
    assert_text "Notificação atualizada."
    assert_text "Negativo"
    assert_text "Alterada por @operador_teste"
  end

  test "erros aparecem ao lado das perguntas e o que foi digitado continua lá" do
    sign_in users(:operador)
    visit new_formulario_avaliacao_clinica_path(FORMULARIO)

    fill_in "campo_municipio_residencia", with: "Cidade Digitada"
    click_on "Registrar notificação"

    assert_current_path formulario_avaliacoes_clinicas_path(FORMULARIO)
    assert_text "Não foi possível registrar. Revise as perguntas destacadas."
    assert_selector "#campo_iniciais[aria-invalid='true']"
    assert_field "campo_municipio_residencia", with: "Cidade Digitada"
  end

  test "consultor navega e consulta, sem nenhum caminho de escrita" do
    sign_in users(:consultor)
    visit root_path

    # O atalho da visão geral leva à lista do formulário; a trilha do topo diz onde a pessoa está
    within("main") { click_on "Acompanhamento de teste" }
    assert_current_path formulario_avaliacoes_clinicas_path(FORMULARIO)
    assert_selector "nav[aria-label='Você está em'] [aria-current='page']", text: /acompanhamento de teste/i
    assert_no_link "Nova notificação"
    assert_text "MFU"
    assert_no_link "Editar"

    click_on "Ver", match: :first
    assert_current_path %r{/avaliacoes/\d+\z}
    assert_text "Histórico de alterações"
    assert_no_link "Editar"
  end

  test "sair volta para o login com o aviso" do
    sign_in users(:admin)
    visit root_path
    find("summary[title='Minha conta']").click
    click_on "Sair"

    assert_current_path new_user_session_path
    assert_text "Você saiu do sistema."
    assert_field "user_login"
  end

  private

  # Clica nas opções pelo id, como uma pessoa clicaria no rótulo
  def marcar(*ids)
    ids.each { |id| find("label[for='#{id}']").click }
  end
end
