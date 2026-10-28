# O que muda de uma versão do formulário para a outra, para o admin revisar
# antes de publicar: perguntas novas, removidas e alteradas (enunciado, tipo,
# opções, obrigatoriedade, condição, limites) e mudanças no cabeçalho
# (inclusive finalidade e base legal). A comparação é pela chave da pergunta,
# que nunca muda nem é reaproveitada (EdicaoDoRascunho).
class ComparacaoDeVersoes
  Alteracao = Data.define(:pergunta, :mudancas)

  CABECALHO = { titulo: "título", descricao: "descrição", finalidade: "finalidade", base_legal: "base legal",
                numeracao: "numeração", campo_encerramento: "pergunta de encerramento" }.freeze
  LIMITES = { maximo: "máximo", minimo: "mínimo", decimais: "casas decimais", nao_maior_que: "comparação",
              nao_antes_de: "comparação", permite_futuro: "data futura" }.freeze
  private_constant :CABECALHO, :LIMITES

  attr_reader :anterior, :nova

  # anterior: nil quando o formulário nunca foi publicado
  def initialize(anterior, nova)
    @anterior = anterior
    @nova = nova
  end

  def primeira_versao?
    anterior.nil?
  end

  def novas
    return nova.perguntas if primeira_versao?

    nova.perguntas.reject { |pergunta| anterior.pergunta(pergunta.chave) }
  end

  def removidas
    return [] if primeira_versao?

    anterior.perguntas.reject { |pergunta| nova.pergunta(pergunta.chave) }
  end

  def alteradas
    return [] if primeira_versao?

    nova.perguntas.filter_map do |pergunta|
      antes = anterior.pergunta(pergunta.chave) or next
      mudancas = mudancas_da_pergunta(antes, pergunta)
      Alteracao.new(pergunta:, mudancas:) if mudancas.any?
    end
  end

  # Campos do cabeçalho que mudaram, pelo nome que aparece na tela
  def cabecalho
    return [] if primeira_versao?

    CABECALHO.filter_map { |metodo, nome| nome if anterior.public_send(metodo) != nova.public_send(metodo) }
  end

  def secoes_mudaram?
    !primeira_versao? && anterior.secoes.map { |secao| [ secao.titulo, secao.descricao ] } != nova.secoes.map { |secao| [ secao.titulo, secao.descricao ] }
  end

  def ordem_mudou?
    !primeira_versao? && (anterior.chaves & nova.chaves) != (nova.chaves & anterior.chaves)
  end

  def sem_mudancas?
    !primeira_versao? && novas.empty? && removidas.empty? && alteradas.empty? && cabecalho.empty? && !secoes_mudaram? && !ordem_mudou?
  end

  private

  def mudancas_da_pergunta(antes, depois)
    mudancas = []
    mudancas << "enunciado" if antes.texto != depois.texto
    # Na numeração automática, o número muda sozinho quando outra pergunta
    # entra ou sai: só conta a troca feita pelo admin, na manual
    mudancas << "número" if antes.numero != depois.numero && [ anterior, nova ].all? { |definicao| definicao.numeracao == "manual" }
    mudancas << "tipo (#{antes.nome_do_tipo} → #{depois.nome_do_tipo})" if antes.tipo != depois.tipo
    mudancas << "obrigatoriedade" if antes.obrigatoria != depois.obrigatoria
    mudancas << "texto de ajuda" if antes.ajuda != depois.ajuda
    mudancas << "condição" if antes.condicao != depois.condicao
    mudancas.concat(mudancas_das_opcoes(antes, depois))
    mudancas.concat(LIMITES.filter_map { |campo, nome| nome if antes.public_send(campo) != depois.public_send(campo) }.uniq)
    mudancas
  end

  def mudancas_das_opcoes(antes, depois)
    rotulos_antes = antes.opcoes.to_h { |opcao| [ opcao.codigo, opcao.rotulo ] }
    rotulos_depois = depois.opcoes.to_h { |opcao| [ opcao.codigo, opcao.rotulo ] }
    mudancas = []
    (rotulos_depois.keys - rotulos_antes.keys).each { |codigo| mudancas << "opção nova: #{codigo}, #{rotulos_depois[codigo]}" }
    (rotulos_antes.keys - rotulos_depois.keys).each { |codigo| mudancas << "opção removida: #{codigo}, #{rotulos_antes[codigo]}" }
    (rotulos_antes.keys & rotulos_depois.keys).each do |codigo|
      next if rotulos_antes[codigo] == rotulos_depois[codigo]

      mudancas << "opção #{codigo} renomeada: “#{rotulos_antes[codigo]}” → “#{rotulos_depois[codigo]}”"
    end
    mudancas << "opções exclusivas" if antes.opcoes.select(&:exclusiva).map(&:codigo) != depois.opcoes.select(&:exclusiva).map(&:codigo)
    mudancas << "ordem das opções" if (rotulos_antes.keys & rotulos_depois.keys) != (rotulos_depois.keys & rotulos_antes.keys)
    mudancas
  end
end
