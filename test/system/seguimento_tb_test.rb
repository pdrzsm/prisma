require "application_system_test_case"

class SeguimentoTbTest < ApplicationSystemTestCase
  FORMULARIO = "seguimento_tb".freeze

  test "a pergunta 10 só aparece para forma clínica extrapulmonar" do
    sign_in users(:operador)
    visit new_formulario_avaliacao_clinica_path(FORMULARIO)

    assert_no_text "Se extrapulmonar, qual?"
    assert_no_selector "#campo_tb_extrapulmonar_1", visible: true

    marcar "campo_forma_clinica_2" # Extrapulmonar
    assert_text "Se extrapulmonar, qual?"
    assert_selector "#campo_tb_extrapulmonar_1", visible: true

    marcar "campo_forma_clinica_1" # Pulmonar
    assert_no_text "Se extrapulmonar, qual?"

    marcar "campo_forma_clinica_3" # Pulmonar + extrapulmonar
    assert_text "Se extrapulmonar, qual?"
  end

  test "operador registra uma notificação e depois atualiza o seguimento" do
    sign_in users(:operador)
    visit formularios_path
    click_on "Nova notificação"

    fill_in "campo_prontuario_sah", with: "sah 7777"
    fill_in "campo_iniciais", with: "r. t. s."
    fill_in "campo_numero_sinan", with: "7654321"
    marcar "campo_gestante_6", "campo_populacoes_especiais_0", "campo_recebe_beneficio_0", "campo_forma_clinica_2",
           "campo_tb_extrapulmonar_1"
    fill_in "campo_municipio_residencia", with: "Cidade Fictícia"
    click_on "Registrar notificação"

    # Espera a página nova antes de ler o texto. Sem isso, o Chrome às vezes
    # inspeciona a página antiga no meio da navegação e o teste falha à toa.
    assert_current_path %r{/avaliacoes/\d+\z}
    assert_text "Notificação registrada."
    assert_text "Notificação · RTS"
    assert_text "SAH7777"
    assert_text "Pleural"
    assert_text "Em acompanhamento"

    click_on "Editar"
    assert_no_field "campo_iniciais" # identificação só para leitura
    marcar "campo_baciloscopia_escarro_mes_1_2"
    click_on "Salvar alterações"

    assert_current_path %r{/avaliacoes/\d+\z}
    assert_text "Notificação atualizada."
    assert_text "Negativa"
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

    within("aside") { click_on "Formulários" } # a visão geral também cita Formulários no texto
    assert_current_path formularios_path
    # O menu é exibido em caixa alta (CSS), e o navegador devolve o texto como aparece
    assert_selector "nav a[aria-current='page']", text: /\Aformulários\z/i
    assert_no_link "Nova notificação"

    click_on "Ver registros"
    assert_current_path formulario_avaliacoes_clinicas_path(FORMULARIO)
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
