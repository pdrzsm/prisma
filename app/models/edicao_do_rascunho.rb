# As mudanças que o gerador de formulários faz num rascunho, uma por clique:
# o cabeçalho, e acrescentar, alterar, mover e remover seções e perguntas.
#
# Cada mudança parte da estrutura gravada, muda uma coisa e grava a estrutura
# inteira de novo. Quem confere o resultado é o DefinicaoDeFormulario (pela
# validação do VersaoFormulario): uma mudança que deixaria a definição
# inválida não grava nada, e os erros ficam em rascunho.errors. O
# lock_version vem da tela: se o rascunho mudou depois que a tela foi aberta
# (outra aba), a gravação levanta ActiveRecord::StaleObjectError.
#
# A chave de uma pergunta nova é gerada aqui, a partir do enunciado, e nunca
# repete uma chave usada em qualquer versão do formulário: uma pergunta
# removida e outra criada depois não se confundem nas respostas.
class EdicaoDoRascunho
  # Mudança que não se aplica (ex.: remover uma pergunta usada como coluna da lista)
  class Recusada < StandardError; end

  DIRECOES = %w[acima abaixo].freeze

  attr_reader :rascunho

  def initialize(rascunho, lock_version:)
    raise ArgumentError, "só um rascunho é editado" unless rascunho.rascunho?

    # Sem a versão que a tela viu, não há como saber se o rascunho mudou: recusa
    vista = Integer(lock_version.to_s, 10, exception: false) or raise ActiveRecord::StaleObjectError.new(rascunho, "editar")
    @rascunho = rascunho
    @rascunho.lock_version = vista
  end

  # numeracao: ao passar para "manual", cada pergunta recebe o número que já
  # mostrava; ao voltar para "automatica", os números próprios saem
  def atualizar_cabecalho(titulo:, descricao:, finalidade:, base_legal:, numeracao:, encerramento:, lista:)
    mudar do |estrutura|
      estrutura.merge!("titulo" => titulo, "descricao" => descricao.presence, "finalidade" => finalidade.presence,
                       "base_legal" => base_legal.presence, "encerramento" => encerramento.presence,
                       "lista" => Array(lista).compact_blank)
      trocar_numeracao(estrutura, numeracao)
    end
  end

  def adicionar_secao(titulo:, descricao:)
    mudar do |estrutura|
      ids = estrutura["secoes"].map { |secao| secao["id"].delete_prefix("s").to_i }
      estrutura["secoes"] << { "id" => "s#{(ids.max || 0) + 1}", "titulo" => titulo, "descricao" => descricao.presence, "perguntas" => [] }
    end
  end

  def atualizar_secao(id, titulo:, descricao:)
    mudar { |estrutura| secao!(estrutura, id).merge!("titulo" => titulo, "descricao" => descricao.presence) }
  end

  # Só seção vazia sai: as perguntas são removidas ou movidas antes, uma a uma
  def remover_secao(id)
    mudar do |estrutura|
      secao = secao!(estrutura, id)
      raise Recusada, "Remova ou mova as perguntas da seção antes de removê-la." if secao["perguntas"].any?

      estrutura["secoes"].delete(secao)
    end
  end

  def mover_secao(id, direcao)
    mudar do |estrutura|
      secoes = estrutura["secoes"]
      origem = secoes.index(secao!(estrutura, id))
      destino = origem + deslocamento(direcao)
      raise Recusada, "Não há para onde mover a seção." unless destino.between?(0, secoes.size - 1)

      secoes[origem], secoes[destino] = secoes[destino], secoes[origem]
    end
  end

  # atributos: a pergunta no formato da estrutura, sem chave nem condição
  # (PerguntaDoGerador#atributos). Com controladora, a pergunta nova entra no
  # fim das que já dependem dela e só aparece com as opções de valores.
  # Devolve a chave gerada (nil se não gravou).
  def adicionar_pergunta(secao_id:, atributos:, controladora: nil, valores: nil)
    chave = nova_chave(atributos["texto"])
    gravou = mudar do |estrutura|
      pergunta = atributos.merge("chave" => chave)
      if controladora
        _pai, secao = pergunta!(estrutura, controladora)
        pergunta["condicao"] = { "pergunta" => controladora, "valores" => Array(valores) }
        secao["perguntas"].insert(subarvore(secao["perguntas"], controladora).end, pergunta)
      else
        secao!(estrutura, secao_id)["perguntas"] << pergunta
      end
    end
    chave if gravou
  end

  # A condição continua a mesma pergunta controladora; valores troca as opções
  # que a mostram
  def atualizar_pergunta(chave, atributos, valores: nil)
    mudar do |estrutura|
      pergunta, _secao = pergunta!(estrutura, chave)
      condicao = pergunta["condicao"]
      pergunta.replace(atributos.merge("chave" => chave))
      pergunta["condicao"] = condicao.merge("valores" => Array(valores)) if condicao
    end
  end

  # Remove a pergunta e as que dependem dela. Recusa se alguma delas é usada
  # fora desse grupo: como coluna da lista, encerramento ou comparação.
  def remover_pergunta(chave)
    mudar do |estrutura|
      _pergunta, secao = pergunta!(estrutura, chave)
      faixa = subarvore(secao["perguntas"], chave)
      removidas = secao["perguntas"][faixa].map { |pergunta| pergunta["chave"] }
      usos = usos_fora(estrutura, removidas)
      raise Recusada, "Antes de remover, tire a pergunta de: #{usos.to_sentence}." if usos.any?

      secao["perguntas"].slice!(faixa)
    end
  end

  # Move a pergunta (com as que dependem dela) para antes ou depois da vizinha
  # do mesmo nível. Sem condição, a primeira de uma seção sobe para o fim da
  # seção de cima, e a última desce para o começo da de baixo.
  def mover_pergunta(chave, direcao)
    mudar do |estrutura|
      pergunta, secao = pergunta!(estrutura, chave)
      perguntas = secao["perguntas"]
      irmas = perguntas.each_index.select { |indice| perguntas[indice].dig("condicao", "pergunta") == pergunta.dig("condicao", "pergunta") }
      posicao = irmas.index(perguntas.index(pergunta))
      vizinha = irmas[posicao + deslocamento(direcao)] if (posicao + deslocamento(direcao)).between?(0, irmas.size - 1)

      if vizinha
        trocar_vizinhas(perguntas, chave, perguntas[vizinha]["chave"])
      elsif pergunta["condicao"].nil?
        mudar_de_secao(estrutura, secao, chave, direcao)
      else
        raise Recusada, "Não há para onde mover a pergunta."
      end
    end
  end

  private

  # Aplica a mudança numa cópia da estrutura e grava. Recusada vira erro, sem gravar.
  def mudar
    rascunho.errors.clear
    estrutura = JSON.parse(JSON.generate(rascunho.estrutura))
    estrutura["secoes"] = [] unless estrutura["secoes"].is_a?(Array)
    yield estrutura
    rascunho.estrutura = estrutura
    rascunho.save
  rescue Recusada => e
    rascunho.errors.add(:base, e.message)
    false
  end

  def deslocamento(direcao)
    raise Recusada, "Direção desconhecida." unless DIRECOES.include?(direcao.to_s)

    direcao.to_s == "acima" ? -1 : 1
  end

  def secao!(estrutura, id)
    estrutura["secoes"].find { |secao| secao["id"] == id.to_s } || raise(ActiveRecord::RecordNotFound, "Seção #{id} não existe")
  end

  # A pergunta e a seção em que ela está
  def pergunta!(estrutura, chave)
    estrutura["secoes"].each do |secao|
      pergunta = secao["perguntas"].find { |candidata| candidata["chave"] == chave.to_s }
      return [ pergunta, secao ] if pergunta
    end
    raise ActiveRecord::RecordNotFound, "Pergunta #{chave} não existe"
  end

  # Posições da pergunta e das que dependem dela, direta ou indiretamente: em
  # pré-ordem, elas vêm logo depois dela
  def subarvore(perguntas, chave)
    inicio = perguntas.index { |pergunta| pergunta["chave"] == chave }
    controladoras = perguntas.to_h { |pergunta| [ pergunta["chave"], pergunta.dig("condicao", "pergunta") ] }
    fim = inicio + 1
    fim += 1 while fim < perguntas.size && descende?(perguntas[fim]["chave"], chave, controladoras)
    inicio...fim
  end

  def descende?(chave, ancestral, controladoras)
    atual = controladoras[chave]
    while atual
      return true if atual == ancestral

      atual = controladoras[atual]
    end
    false
  end

  def trocar_vizinhas(perguntas, chave, vizinha)
    primeira, segunda = [ subarvore(perguntas, chave), subarvore(perguntas, vizinha) ].sort_by(&:begin)
    perguntas[primeira.begin...segunda.end] = perguntas[segunda] + perguntas[primeira]
  end

  def mudar_de_secao(estrutura, secao, chave, direcao)
    secoes = estrutura["secoes"]
    destino = secoes[secoes.index(secao) + deslocamento(direcao)] if (secoes.index(secao) + deslocamento(direcao)).between?(0, secoes.size - 1)
    raise Recusada, "Não há para onde mover a pergunta." unless destino

    grupo = secao["perguntas"].slice!(subarvore(secao["perguntas"], chave))
    direcao.to_s == "acima" ? destino["perguntas"].concat(grupo) : destino["perguntas"].unshift(*grupo)
  end

  # Onde as perguntas removidas são usadas fora do grupo removido
  def usos_fora(estrutura, removidas)
    usos = []
    usos << "colunas da lista" if (Array(estrutura["lista"]) & removidas).any?
    usos << "pergunta de encerramento" if removidas.include?(estrutura["encerramento"])
    estrutura["secoes"].flat_map { |secao| secao["perguntas"] }.each do |pergunta|
      next if removidas.include?(pergunta["chave"])

      referencia = pergunta.values_at("nao_maior_que", "nao_antes_de").compact & removidas
      usos << "comparação de “#{pergunta["texto"]}”" if referencia.any?
    end
    usos
  end

  def trocar_numeracao(estrutura, numeracao)
    anterior = estrutura["numeracao"] || "automatica"
    estrutura["numeracao"] = numeracao
    perguntas = estrutura["secoes"].flat_map { |secao| secao["perguntas"] }
    if numeracao == "manual" && anterior != "manual"
      perguntas.each_with_index { |pergunta, indice| pergunta["numero"] = (indice + 1).to_s }
    elsif numeracao != "manual"
      perguntas.each { |pergunta| pergunta.delete("numero") }
    end
  end

  # Chave a partir do enunciado ("Peso ao nascer" vira "peso_ao_nascer"), sem
  # repetir nenhuma chave de nenhuma versão do formulário nem uma reservada
  def nova_chave(texto)
    base = I18n.transliterate(TextoSeguro.linha(texto)).downcase.gsub(/[^a-z0-9]+/, "_").sub(/\A[_0-9]+/, "").first(40).delete_suffix("_")
    base = "pergunta" if base.empty?
    indisponiveis = chaves_ja_usadas + DefinicaoDeFormulario::CHAVES_RESERVADAS
    candidata = base
    candidata = "#{base}_#{(numero = (numero || 1) + 1)}" while indisponiveis.include?(candidata)
    candidata
  end

  def chaves_ja_usadas
    estruturas = rascunho.formulario.versoes.where.not(id: rascunho.id).select(:id, :estrutura).map(&:estrutura) << rascunho.estrutura
    estruturas.flat_map { |estrutura| Array(estrutura["secoes"]).flat_map { |secao| Array(secao["perguntas"]).map { |pergunta| pergunta["chave"] } } }.to_set
  end
end
