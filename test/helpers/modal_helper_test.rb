require "test_helper"

class ModalHelperTest < ActionView::TestCase
  include IconesHelper

  # Desenha um modal do zero: cada chamada de modal acrescenta ao que já estava em content_for
  def janela(**opcoes)
    content_for :modal, "", flush: true
    modal("Nova coisa", fechar: "/volta", **opcoes) { "conteúdo" }
    Nokogiri::HTML5.fragment(content_for(:modal))
  end

  test "o modal é uma janela no centro da tela, com título, descrição e o X que volta" do
    html = janela(descricao: "Onde ela entra.")
    dialog = html.at_css("dialog.modal[open]")

    assert_equal "true", dialog["aria-modal"]
    assert_equal "modal_titulo", dialog["aria-labelledby"]
    assert_equal "modal_descricao", dialog["aria-describedby"]
    # No meio da tela, nos dois sentidos, e não encostado numa borda
    assert_includes dialog[:class].split, "items-center"
    assert_includes dialog[:class].split, "justify-center"
    assert_not_includes dialog[:class].split, "ml-auto"
    assert_nil html.at_css("aside")
    assert_equal "Nova coisa", html.at_css("h1#modal_titulo").text
    assert_equal "Onde ela entra.", html.at_css("p#modal_descricao").text
    assert_equal "/volta", html.at_css("a[aria-label=Fechar]")["href"]
  end

  test "a largura é a pedida, e a janela nunca passa da altura da tela" do
    padrao = janela.at_css("dialog > section")
    larga = janela(largura: "max-w-2xl").at_css("dialog > section")

    assert_includes padrao[:class].split, "max-w-xl"
    assert_includes larga[:class].split, "max-w-2xl"
    assert_not_includes larga[:class].split, "max-w-xl"
    assert_includes larga[:class].split, "max-h-full"
  end

  test "o corpo rola por dentro; com rodapé, quem rola é o formulário que o bloco traz" do
    simples = janela.at_css("dialog > section > div:last-child")
    assert_includes simples[:class].split, "overflow-y-auto"

    com_rodape = janela(rodape: true).at_css("dialog > section > div:last-child")
    assert_not_includes com_rodape[:class].split, "overflow-y-auto"
    assert_includes com_rodape[:class].split, "flex-col"
  end
end
