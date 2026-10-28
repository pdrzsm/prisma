require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # As larguras (em rem) a partir das quais cada nível da trilha aparece, na ordem dos níveis
  def larguras_da_trilha
    Nokogiri::HTML5.fragment(content_for(:trilha)).css("li").map do |nivel|
      nivel[:class][/@min-\[(\d+)rem\]/, 1]&.to_i
    end
  end

  test "a trilha tem todos os níveis na página, a atual em negrito e sem quebrar de linha" do
    trilha [ "Formulários", "/formularios" ], [ "Seguimento de TB" ]
    html = Nokogiri::HTML5.fragment(content_for(:trilha))

    assert_equal [ "Formulários/", "Seguimento de TB" ], html.css("li").map { |nivel| nivel.text.squish }
    assert_equal "Seguimento de TB", html.at_css("[aria-current=page]").text
    assert_includes html.at_css("ol")[:class], "flex-nowrap"
    assert_not_includes html.at_css("ol")[:class], "flex-wrap"
    assert_includes html.at_css("nav")[:class], "@container"
  end

  test "a página atual está sempre à vista e os outros níveis só aparecem quando cabem" do
    trilha [ "Configurações", "/c" ], [ "Gerador de formulários", "/g" ], [ "CHECKLIST TI", "/f" ], [ "Rascunho da versão 1" ]
    niveis = Nokogiri::HTML5.fragment(content_for(:trilha)).css("li")

    assert_equal %w[flex], niveis.last[:class].split & %w[hidden flex]
    niveis[0..-2].each { |nivel| assert_includes nivel[:class].split, "hidden" }
    # Quanto mais cedo o nível, mais largura ele pede
    pedidos = larguras_da_trilha[0..-2]
    assert_equal pedidos.sort.reverse, pedidos
    assert_equal pedidos.uniq, pedidos
  end

  test "a largura pedida vem do tamanho dos textos" do
    trilha [ "Início", "/" ], [ "Atual" ]
    curta = larguras_da_trilha.first
    # Cada chamada acrescenta à trilha anterior: começa de novo
    content_for :trilha, "", flush: true
    trilha [ "Um nível com um nome bem comprido, de verdade", "/" ], [ "Atual" ]

    assert_operator larguras_da_trilha.first, :>, curta
  end

  test "a seta de voltar leva ao nível de cima que tem caminho" do
    trilha [ "Configurações", "/c" ], [ "Grupo sem tela" ], [ "Atual" ]

    assert_equal "/c", content_for(:voltar_caminho)
    assert_equal "Configurações", content_for(:voltar_texto)
  end

  test "um nível só não tem seta de voltar" do
    trilha [ "Visão geral" ]

    assert_not content_for?(:voltar_caminho)
  end
end
