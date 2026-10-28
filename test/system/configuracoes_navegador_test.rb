require "application_system_test_case"

# Configurações no navegador: os interruptores e os segmentos (só CSS) e os
# modais (sem JavaScript, com a página de fundo inerte).
class ConfiguracoesNavegadorTest < ApplicationSystemTestCase
  FORMULARIO = "acompanhamento".freeze

  setup do
    @centro = instituicoes(:centro)
    @ambulatorio = setores(:ambulatorio)
    @laboratorio = setores(:laboratorio)
    sign_in users(:admin)
  end

  test "liberações com interruptores e segmentos, pelo clique e pelo teclado" do
    pessoa = users(:sem_acesso)
    visit edit_configuracoes_usuario_liberacoes_path(pessoa)

    # Instituição desligada: tudo o que está dentro dela fica apagado
    assert_equal "0.45", opacidade("#liberacoes_instituicao_#{@centro.id} .liberacao-dentro")

    # Clique em qualquer ponto da linha liga o interruptor
    find("label[for='liberacao_instituicao_#{@centro.id}']").click
    assert_selector "#liberacao_instituicao_#{@centro.id}:checked"
    assert_equal "1", opacidade("#liberacoes_instituicao_#{@centro.id} > div > .liberacao > .liberacao-dentro")

    # Espaço liga o do setor, como numa caixa de marcar
    find("#liberacao_setor_#{@ambulatorio.id}").send_keys(:space)
    assert_selector "#liberacao_setor_#{@ambulatorio.id}:checked"
    # O laboratório continua desligado e apagado
    assert_equal "0.45", opacidade("#liberacao_setor_#{@laboratorio.id}", "closest('.liberacao').querySelector('.liberacao-dentro')")

    # O segmento marcado é o rádio escondido atrás do rótulo
    find("label[for='liberacao_#{@ambulatorio.id}_#{FORMULARIO}_consulta']").click
    assert_selector "#liberacao_#{@ambulatorio.id}_#{FORMULARIO}_consulta:checked", visible: :all
    # O clique deixa o foco no rádio, e as setas trocam o segmento
    assert_equal "liberacao_#{@ambulatorio.id}_#{FORMULARIO}_consulta", evaluate_script("document.activeElement.id")
    page.send_keys(:right)
    assert_selector "#liberacao_#{@ambulatorio.id}_#{FORMULARIO}_registra:checked", visible: :all

    click_on "Salvar liberações"
    assert_text "Liberações de #{pessoa.nome} salvas."
    assert_equal({ [ @ambulatorio.id, FORMULARIO ] => "registra" }, pessoa.reload.permissoes.acessos)
  end

  test "o setor é cadastrado num modal, sem sair da lista" do
    visit configuracoes_instituicoes_path
    find("a[href='#{new_configuracoes_instituicao_setor_path(@centro)}']").click

    within("dialog.modal[open]") do
      assert_selector "h1", text: "Novo setor"
      fill_in "Nome do setor", with: "Triagem"
      find("label[for='setor_formulario_#{FORMULARIO}']").click
      click_on "Cadastrar setor"
    end

    assert_no_selector "dialog.modal"
    assert_text "Setor cadastrado."
    assert_equal [ FORMULARIO ], @centro.setores.find_by!(nome: "Triagem").formularios
  end

  test "com o modal aberto, o fundo fica inerte e não rola; Fechar volta para a lista" do
    visit edit_configuracoes_usuario_path(users(:operador))

    # O foco começa no próprio modal, e o Tab anda dentro dele
    assert_selector "dialog.modal:focus"
    find("dialog.modal").send_keys(:tab)
    assert_selector "dialog.modal a[aria-label='Fechar']:focus"
    # Para trás, o foco não cai em nada da página de fundo
    find("dialog.modal a[aria-label='Fechar']").send_keys(%i[shift tab], %i[shift tab])
    assert_not evaluate_script("!!document.activeElement.closest('[inert]')"), "o foco foi para a página de fundo"
    assert_equal "hidden", evaluate_script("getComputedStyle(document.body).overflow")

    find("dialog.modal a[aria-label='Fechar']").click
    assert_current_path configuracoes_usuarios_path
    assert_no_selector "dialog.modal"
    assert_selector "[inert]", count: 0, visible: :all
    assert_equal "visible", evaluate_script("getComputedStyle(document.body).overflow")
  end

  private

  # Opacidade calculada do elemento (ou de um parente dele, pelo caminho em JS)
  def opacidade(seletor, caminho = nil)
    elemento = "document.querySelector(#{seletor.to_json})"
    elemento = "#{elemento}.#{caminho}" if caminho
    evaluate_script("getComputedStyle(#{elemento}).opacity")
  end
end
