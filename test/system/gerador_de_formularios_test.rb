require "application_system_test_case"

# No navegador: as perguntas que dependem de outra aparecem e somem só com
# CSS (em três níveis, com lista suspensa e múltipla escolha), e o gerador
# mostra os campos do tipo escolhido. Do jeito que uma pessoa usa.
class GeradorDeFormulariosNavegadorTest < ApplicationSystemTestCase
  test "as perguntas aparecem e somem conforme a resposta, em três níveis" do
    formulario = publicar_formulario("todos_os_tipos", FormulariosDeTeste::TODOS_OS_TIPOS)
    setores(:ambulatorio).formularios_habilitados.create!(formulario: formulario.chave)
    users(:operador).liberacoes_formulario.create!(setor: setores(:ambulatorio), formulario: formulario.chave, papel: "registra")
    sign_in users(:operador)
    visit new_formulario_avaliacao_clinica_path(formulario)

    escondidas = [ "Internado?", "Na UTI?", "Dias na UTI", "Temperatura máxima", "Dias de tosse" ]
    escondidas.each { |texto| assert_no_text texto }

    select "Grave", from: "campo_gravidade"
    assert_text "Internado?"
    assert_no_text "Na UTI?"
    marcar "campo_internado_1"
    assert_text "Na UTI?"
    marcar "campo_uti_1"
    assert_text "Dias na UTI"
    assert_selector "#campo_dias_de_uti", visible: true

    # Trocar a resposta lá de cima esconde os três níveis de uma vez
    select "Leve", from: "campo_gravidade"
    [ "Internado?", "Na UTI?", "Dias na UTI" ].each { |texto| assert_no_text texto }
    select "Grave", from: "campo_gravidade"
    assert_text "Dias na UTI" # a resposta marcada continua lá

    # Múltipla escolha: cada opção mostra a sua pergunta
    marcar "campo_sintomas_1"
    assert_text "Temperatura máxima"
    assert_no_text "Dias de tosse"
    marcar "campo_sintomas_2"
    assert_text "Dias de tosse"
    marcar "campo_sintomas_1"
    assert_no_text "Temperatura máxima"
    assert_text "Dias de tosse"
  end

  test "registrar pela tela: a resposta de uma pergunta que sumiu não é gravada" do
    formulario = publicar_formulario("todos_os_tipos", FormulariosDeTeste::TODOS_OS_TIPOS)
    setores(:ambulatorio).formularios_habilitados.create!(formulario: formulario.chave)
    users(:operador).liberacoes_formulario.create!(setor: setores(:ambulatorio), formulario: formulario.chave, papel: "registra")
    sign_in users(:operador)
    visit new_formulario_avaliacao_clinica_path(formulario)

    fill_in "campo_prontuario_sah", with: "SAH-NAVEGADOR"
    fill_in "campo_iniciais", with: "NV"
    fill_in "campo_apelido", with: "Teste no navegador"
    fill_in "campo_peso", with: "70.25"
    select "Grave", from: "campo_gravidade"
    marcar "campo_internado_1"
    marcar "campo_uti_1"
    fill_in "campo_dias_de_uti", with: "4"
    select "Leve", from: "campo_gravidade" # a UTI some, com o que foi digitado nela
    click_on "Registrar notificação"

    assert_current_path %r{/avaliacoes/\d+\z}
    assert_text "Notificação registrada."
    assert_text "70,25"
    respostas = AvaliacaoClinica.order(:id).last.respostas
    assert_equal "2", respostas["gravidade"]
    assert_not respostas.key?("dias_de_uti")
    assert_not respostas.key?("internado")
  end

  test "no gerador, os campos de cada tipo aparecem conforme o tipo escolhido" do
    sign_in users(:admin)
    acompanhamento = formularios(:acompanhamento)
    acompanhamento.versoes.create!(numero: 2, estrutura: acompanhamento.versao_publicada.estrutura)
    visit new_configuracoes_formulario_rascunho_pergunta_path(acompanhamento, secao: "s2")

    assert_field "Limite de caracteres da resposta"
    assert_no_field "Opções"
    assert_no_field "Valor mínimo"

    select "Número", from: "Tipo de resposta"
    assert_field "Valor mínimo"
    assert_field "Casas decimais"
    assert_no_field "Limite de caracteres da resposta"

    select "Múltipla escolha", from: "Tipo de resposta"
    assert_field "Opções"
    assert_field "Opções exclusivas (opcional)"
    assert_no_field "Valor mínimo"

    select "Lista suspensa", from: "Tipo de resposta"
    assert_field "Opções"
    assert_no_field "Opções exclusivas (opcional)"

    select "Data", from: "Tipo de resposta"
    assert_field "Aceita data futura (ex.: data prevista de retorno). Sem marcar, só até hoje.", type: "checkbox"
  end

  test "a pergunta abre num modal por cima do rascunho, com as ações à vista, e o cabeçalho não some atrás do topo ao salvar" do
    sign_in users(:admin)
    acompanhamento = formularios(:acompanhamento)
    acompanhamento.versoes.create!(numero: 2, estrutura: acompanhamento.versao_publicada.estrutura)
    visit configuracoes_formulario_rascunho_path(acompanhamento)

    # O cabeçalho da tela fica numa linha só, com a altura da faixa do logo, qualquer que seja a trilha
    assert_equal 61, altura("body header")

    # A nova pergunta abre num modal, com a seção dela à vista atrás
    first(:link, "Nova pergunta nesta seção").click
    assert_selector "dialog.modal[open]"
    assert_modal_no_centro
    assert_operator topo("s1"), :>=, altura("body header")
    within("dialog.modal[open]") do
      assert_selector "h1", text: "Nova pergunta"
      select "Múltipla escolha", from: "Tipo de resposta"
      assert_field "Opções exclusivas (opcional)"
      assert_button "Criar pergunta" # o rodapé do modal fica à vista
      click_on "Criar pergunta"
      assert_text "não pode ficar em branco"
      fill_in "Enunciado", with: "Qual o turno?"
      fill_in "Número", with: "99"
      fill_in "Opções", with: "1, Manhã\n2, Tarde"
      click_on "Criar pergunta"
    end
    assert_text "Pergunta criada."
    assert_no_selector "dialog.modal[open]"
    assert_operator topo("pergunta-qual_o_turno"), :>=, altura("body header")

    # Editar e remover também abrem no modal; Cancelar volta ao rascunho
    within("#pergunta-qual_o_turno") { click_on "Editar" }
    assert_selector "dialog.modal[open] h1", text: "Editar pergunta 99"
    within("dialog.modal[open]") { click_on "Cancelar" }
    assert_no_selector "dialog.modal[open]"
    within("#pergunta-qual_o_turno") { click_on "Remover" }
    assert_selector "dialog.modal[open] h1", text: "Remover do rascunho?"
    within("dialog.modal[open]") { click_on "Remover pergunta" }
    assert_text "Pergunta removida."

    # Salvar o cabeçalho deixa o cartão aberto e à vista, não escondido atrás do topo
    find("#cabecalho summary").click
    within("#cabecalho") do
      fill_in "Título", with: "Acompanhamento renomeado"
      click_on "Salvar cabeçalho"
    end
    assert_selector "#cabecalho[open]"
    assert_text "Cabeçalho salvo."
    assert_operator topo("cabecalho"), :>=, altura("body header")
  end

  test "a seção também abre num modal no centro da tela: criar, editar e remover" do
    sign_in users(:admin)
    acompanhamento = formularios(:acompanhamento)
    acompanhamento.versoes.create!(numero: 2, estrutura: acompanhamento.versao_publicada.estrutura)
    visit configuracoes_formulario_rascunho_path(acompanhamento)

    click_on "Nova seção"
    assert_selector "dialog.modal[open] h1", text: "Nova seção"
    assert_modal_no_centro
    within("dialog.modal[open]") do
      click_on "Criar seção" # sem título
      assert_selector "[role=alert]"
      fill_in "Título da seção", with: "Seção do navegador"
      fill_in "Descrição (opcional)", with: "Orientação para quem preenche"
      click_on "Criar seção"
    end
    assert_text "Seção criada."
    assert_no_selector "dialog.modal[open]"
    assert_selector "h2", text: "Seção do navegador"

    all(:link, "Editar seção").last.click
    assert_selector "dialog.modal[open] h1", text: "Editar seção"
    assert_modal_no_centro
    within("dialog.modal[open]") do
      fill_in "Título da seção", with: "Seção renomeada"
      click_on "Salvar seção"
    end
    assert_text "Seção salva."
    assert_selector "h2", text: "Seção renomeada"

    # Vazia, a seção pode ser removida pelo próprio modal; Cancelar só fecha
    all(:link, "Editar seção").last.click
    within("dialog.modal[open]") { click_on "Cancelar" }
    assert_no_selector "dialog.modal[open]"
    all(:link, "Editar seção").last.click
    within("dialog.modal[open]") { click_on "Remover seção" }
    assert_text "Seção removida."
    assert_no_selector "h2", text: "Seção renomeada"
  end

  test "o admin monta, confere na prévia e publica um formulário pela tela" do
    sign_in users(:admin)
    visit configuracoes_formularios_path
    click_on "Novo formulário"
    within("dialog.modal[open]") do
      fill_in "Título", with: "Triagem respiratória"
      # Os setores só aparecem depois de escolhida a instituição (só CSS)
      centro = instituicoes(:centro)
      assert_no_selector "label[for='do_formulario_setor_#{setores(:ambulatorio).id}']"
      find("label[for='do_formulario_instituicao_#{centro.id}']").click
      find("label[for='do_formulario_setor_#{setores(:ambulatorio).id}']").click
      click_on "Criar rascunho"
    end
    assert_text "Formulário criado."
    formulario = Formulario.find_by!(chave: "triagem_respiratoria")
    assert_equal instituicoes(:centro), formulario.instituicao
    assert_equal [ setores(:ambulatorio).id ], formulario.habilitacoes.map(&:setor_id)

    click_on "Nova seção"
    fill_in "Título da seção", with: "Sintomas"
    click_on "Criar seção"
    click_on "Nova pergunta nesta seção"
    fill_in "Enunciado", with: "Tem tosse?"
    select "Escolha única", from: "Tipo de resposta"
    fill_in "Opções", with: "1, Sim\n2, Não"
    find("label[for='pergunta_obrigatoria_abertura']").click
    click_on "Criar pergunta"
    assert_text "Pergunta criada."

    click_on "Nova pergunta que aparece conforme esta resposta"
    find("label[for='pergunta_valores_1']").click
    fill_in "Enunciado", with: "Há quantos dias?"
    select "Número", from: "Tipo de resposta"
    click_on "Criar pergunta"
    assert_text "Aparece quando “Tem tosse?” for: Sim"

    within("#cabecalho") do
      fill_in "Finalidade da coleta", with: "triar sintomas respiratórios na chegada"
      fill_in "Base legal", with: "tutela da saúde (LGPD, art. 11, II, “f”)"
      click_on "Salvar cabeçalho"
    end
    assert_text "Cabeçalho salvo."

    click_on "Ver a prévia"
    assert_no_text "Há quantos dias?"
    find("label[for='campo_tem_tosse_1']").click
    assert_text "Há quantos dias?"
    click_on "Voltar ao rascunho"

    click_on "Revisar e publicar"
    assert_text "Primeira versão"
    click_on "Publicar a versão 1"
    assert_text "Para publicar, confirme os dois itens da revisão."
    check "A finalidade e a base legal foram validadas com o encarregado de dados (DPO) da instituição."
    check "Cada pergunta é necessária para essa finalidade, e a equipe que usa o formulário conferiu as perguntas, os códigos e as obrigatórias."
    click_on "Publicar a versão 1"
    assert_text "Versão 1 publicada."
    assert Formulario.find_by!(chave: "triagem_respiratoria").publicado?
  end

  private

  # Clica nas opções pelo rótulo, como uma pessoa clicaria
  def marcar(*ids)
    ids.each { |id| find("label[for='#{id}']").click }
  end

  # Altura (px) do elemento e distância dele ao alto da janela
  def altura(seletor) = page.evaluate_script("document.querySelector(#{seletor.to_json}).getBoundingClientRect().height").round

  def topo(id) = page.evaluate_script("document.getElementById(#{id.to_json}).getBoundingClientRect().top").round

  # A janela do modal fica no meio da tela, nos dois sentidos (com até 2 px de folga)
  def assert_modal_no_centro
    janela, tela = page.evaluate_script(<<~JS)
      (() => {
        const r = document.querySelector("dialog.modal[open] > section").getBoundingClientRect();
        return [[r.left + r.width / 2, r.top + r.height / 2], [window.innerWidth / 2, window.innerHeight / 2]];
      })()
    JS
    assert_in_delta tela[0], janela[0], 2, "centro na horizontal"
    assert_in_delta tela[1], janela[1], 2, "centro na vertical"
  end
end
