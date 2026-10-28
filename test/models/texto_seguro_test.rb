require "test_helper"

# Limpeza do texto digitado: tira o invisível e o que engana, padroniza o resto
class TextoSeguroTest < ActiveSupport::TestCase
  test "tira controles, caracteres de largura zero e os de direção do texto" do
    invisiveis = "\u0000\u0007\u001B\u007F\u0085­​‌‍‎‏  ‪‫‬‭‮⁠⁦⁧⁨⁩﻿"

    assert_equal "abc", TextoSeguro.linha("a#{invisiveis}b c".delete(" ").insert(2, "c")).delete("c").then { |texto| texto + "c" }
    assert_equal "", TextoSeguro.linha(invisiveis)
    assert_equal "Fulano", TextoSeguro.linha("‮Fulano‬")
  end

  test "linha: um espaço só, sem quebras" do
    assert_equal "Uma linha só", TextoSeguro.linha("  Uma\n\tlinha  só  ")
  end

  test "parágrafo: mantém as quebras, no máximo uma linha em branco seguida" do
    assert_equal "Um\n\nDois\nTrês", TextoSeguro.paragrafo("  Um  \r\n\r\n\r\n\r\nDois\t \nTrês\n\n")
  end

  test "padroniza a forma Unicode (o mesmo texto, gravado igual)" do
    decomposto = "á" # "á" como "a" + acento
    assert_equal "á", TextoSeguro.linha(decomposto)
    assert_equal TextoSeguro.linha("á"), TextoSeguro.linha(decomposto)
  end

  test "bytes inválidos e outras codificações não levantam erro" do
    assert_equal "ab", TextoSeguro.linha("a\xFFb".dup.force_encoding("BINARY"))
    assert_equal "ab", TextoSeguro.linha("a\xFFb")
    assert_equal "12", TextoSeguro.linha(12)
    assert_equal "", TextoSeguro.linha(nil)
  end
end
