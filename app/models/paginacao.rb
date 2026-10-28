# Onde a pessoa está numa lista paginada (as de notificações): a página, quantas
# há ao todo e o que o rodapé da tabela mostra (o intervalo e os números de
# página, shared/_paginacao).
#
# A página vem da URL, então qualquer valor que não seja um inteiro decimal
# positivo (texto, lista, "0x10", negativo) vira a primeira, e um número depois
# da última é limitado à página seguinte a ela: a lista vem vazia, como antes,
# mas o deslocamento nunca passa do que o banco aceita.
class Paginacao
  attr_reader :pagina, :por_pagina, :total

  def initialize(pagina, por_pagina:, total:)
    @por_pagina = por_pagina
    @total = total
    pedida = Integer(pagina.to_s, 10, exception: false) || 1
    @pagina = pedida.clamp(1, paginas + 1)
  end

  def paginas = [ (total / por_pagina.to_f).ceil, 1 ].max

  # Quantos registros pular no banco (OFFSET)
  def deslocamento = (pagina - 1) * por_pagina

  # A posição, entre todas, da primeira e da última notificação desta página
  def primeiro = deslocamento + 1
  def ultimo = [ deslocamento + por_pagina, total ].min

  def varias? = paginas > 1
  def anterior? = pagina > 1
  def proxima? = pagina < paginas

  # Os números do rodapé: a primeira, a última e a atual com uma vizinha de
  # cada lado. O que sobra no meio vira :lacuna ("…"), menos um buraco de uma
  # página só, que mostra a própria página.
  def numeros
    visiveis = [ 1, pagina - 1, pagina, pagina + 1, paginas ].select { |numero| numero.between?(1, paginas) }.uniq.sort
    visiveis.each_cons(2).with_object([ visiveis.first ]) do |(antes, depois), lista|
      lista << (depois - antes == 2 ? antes + 1 : :lacuna) if depois - antes > 1
      lista << depois
    end
  end
end
