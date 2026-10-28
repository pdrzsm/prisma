# Limpeza de todo texto digitado em formulário: as respostas e o que o admin
# escreve no gerador de formulários (títulos, perguntas, opções). Tira os
# caracteres de controle e os invisíveis, que não servem para nada num
# formulário clínico e podem enganar quem lê (os de direção do texto invertem
# a ordem das letras na tela; os de largura zero fazem dois textos iguais
# parecerem diferentes), e padroniza a forma Unicode e os espaços.
#
# Não é proteção contra HTML: o ERB escapa tudo na hora de mostrar.
module TextoSeguro
  # Controles C0 e C1 (menos quebra de linha e tabulação), largura zero,
  # direção do texto (bidi), separadores Unicode de linha e parágrafo e BOM
  INVISIVEIS = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F­​-‏ -‮⁠-⁤⁦-⁩﻿]/

  module_function

  # Uma linha só: quebras de linha e espaços repetidos viram um espaço
  def linha(valor)
    limpar(valor).squish
  end

  # Texto com parágrafos: mantém as quebras de linha (no máximo uma linha em
  # branco seguida) e tira os espaços do fim de cada linha
  def paragrafo(valor)
    limpar(valor).gsub(/\r\n?/, "\n").tr("\t", " ").gsub(/[  ]+$/, "").gsub(/\n{3,}/, "\n\n").strip
  end

  def limpar(valor)
    texto = valor.to_s
    texto = texto.dup.force_encoding(Encoding::UTF_8) unless texto.encoding == Encoding::UTF_8
    texto.scrub("").unicode_normalize(:nfc).gsub(INVISIVEIS, "")
  end
end
