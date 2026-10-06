# Definição de um formulário clínico: seções, perguntas, opções (com os
# códigos originais) e regras de preenchimento. Cada formulário é um arquivo
# config/formularios/<chave>.yml; o formato está em docs/novo-formulario.md.
#
# As respostas ficam em AvaliacaoClinica#dados_formulario. Esta classe define
# quais chaves existem, como normalizar o que chega do navegador e o que é
# válido; nada fora da definição é aceito.
class Formulario
  Opcao = Data.define(:codigo, :rotulo, :exclusiva)
  Pergunta = Data.define(:numero, :chave, :texto, :tipo, :opcoes, :obrigatoria, :condicao,
                         :paciente, :ajuda, :minimo, :maximo, :nao_maior_que, :nao_antes_de)
  Secao = Data.define(:titulo, :perguntas)

  class DefinicaoInvalida < StandardError; end

  DIRETORIO = Rails.root.join("config/formularios")
  TIPOS = %w[texto numero data unica multipla].freeze
  OBRIGATORIEDADES = [ nil, "abertura", "encerramento" ].freeze
  NOME_DE_CAMPO = /\A[a-z0-9_]{1,64}\z/
  # Perguntas de identificação gravadas no Paciente, não nas respostas
  CAMPOS_DO_PACIENTE = %w[prontuario_sah prontuario_aghuse iniciais].freeze

  attr_reader :chave, :titulo, :descricao, :secoes, :campo_encerramento

  class << self
    def todos
      # Em desenvolvimento relê quando algum YAML muda, para editar sem reiniciar
      if Rails.configuration.enable_reloading
        assinatura = DIRETORIO.glob("*.yml").map { |arquivo| [ arquivo.to_s, arquivo.mtime ] }
        @todos = nil if assinatura != @assinatura
        @assinatura = assinatura
      end

      @todos ||= carregar_todos
    end

    def find(chave)
      todos.find { |formulario| formulario.chave == chave.to_s } ||
        raise(ActiveRecord::RecordNotFound, "Formulário #{chave} não existe")
    end

    def chaves
      todos.map(&:chave)
    end

    private

    def carregar_todos
      DIRETORIO.glob("*.yml").sort.map do |arquivo|
        new(arquivo.basename(".yml").to_s, YAML.safe_load_file(arquivo, aliases: true))
      end.freeze
    end
  end

  def initialize(chave, definicao)
    @chave = chave
    @titulo = definicao.fetch("titulo")
    @descricao = definicao["descricao"]
    @campo_encerramento = definicao["encerramento"]
    @chaves_da_lista = Array(definicao["lista"])
    @secoes = definicao.fetch("secoes").map do |secao|
      Secao.new(titulo: secao.fetch("titulo"), perguntas: secao.fetch("perguntas").map { |atributos| construir_pergunta(atributos) })
    end
    conferir_definicao!
  rescue KeyError => e
    raise DefinicaoInvalida, "#{chave}: #{e.message}"
  end

  def to_param
    chave
  end

  def perguntas
    @perguntas ||= secoes.flat_map(&:perguntas)
  end

  def pergunta(chave)
    perguntas.find { |pergunta| pergunta.chave == chave.to_s }
  end

  def perguntas_do_paciente
    perguntas.select(&:paciente)
  end

  def perguntas_de_resposta
    perguntas.reject(&:paciente)
  end

  # Perguntas mostradas como colunas na lista de registros
  def perguntas_da_lista
    @chaves_da_lista.map { |chave_da_lista| pergunta(chave_da_lista) }
  end

  # Strong params: só as chaves declaradas; múltipla escolha chega como lista
  def parametros_permitidos
    perguntas_de_resposta.map { |pergunta| pergunta.tipo == "multipla" ? { pergunta.chave => [] } : pergunta.chave }
  end

  # Pergunta seguinte que só aparece conforme a resposta desta (ex.: forma
  # clínica -> TB extrapulmonar). O formulário a esconde só com CSS.
  def condicional_seguinte(pergunta)
    secao = secao_de(pergunta)
    seguinte = secao.perguntas[secao.perguntas.index(pergunta) + 1]
    seguinte if seguinte&.condicao&.fetch("pergunta") == pergunta.chave
  end

  def condicao_atendida?(pergunta, respostas)
    return true unless pergunta.condicao

    pergunta.condicao.fetch("valores").include?(respostas[pergunta.condicao.fetch("pergunta")])
  end

  def encerrada?(respostas)
    campo_encerramento.present? && respostas.is_a?(Hash) && respostas[campo_encerramento].present?
  end

  # Converte a entrada (parâmetros do navegador ou JSON salvo) para o formato
  # gravado: textos sem espaços sobrando, números inteiros, listas sem vazios.
  # Perguntas em branco ou fora da condição somem. Chaves desconhecidas são
  # mantidas para a validação recusá-las.
  def normalizar(entrada)
    return entrada unless entrada.is_a?(Hash)

    entrada = entrada.to_h.stringify_keys
    respostas = entrada.except(*perguntas_de_resposta.map(&:chave))
    perguntas_de_resposta.each do |pergunta|
      valor = normalizar_valor(pergunta, entrada[pergunta.chave])
      respostas[pergunta.chave] = valor unless valor.nil?
    end
    respostas.reject { |chave_da_resposta, _| (alvo = pergunta(chave_da_resposta)) && !condicao_atendida?(alvo, respostas) }
  end

  # Erros por pergunta ({ "chave" => ["mensagem"] }). Erros gerais ficam em "base".
  def validar(respostas)
    return { "base" => [ "As respostas devem ser um conjunto de campos." ] } unless respostas.is_a?(Hash)

    erros = Hash.new { |hash, chave| hash[chave] = [] }
    desconhecidas = respostas.keys - perguntas_de_resposta.map(&:chave)
    erros["base"] << "Campos desconhecidos: #{desconhecidas.join(', ')}." if desconhecidas.any?

    encerrada = encerrada?(respostas)
    perguntas_de_resposta.each do |pergunta|
      valor = respostas[pergunta.chave]
      if valor.nil?
        erros[pergunta.chave] << mensagem_de_obrigatoria(pergunta) if obrigatoria?(pergunta, respostas, encerrada)
      else
        validar_valor(pergunta, valor, respostas, erros[pergunta.chave])
      end
    end
    erros.reject { |_, mensagens| mensagens.empty? }
  end

  def obrigatoria?(pergunta, respostas, encerrada = encerrada?(respostas))
    return false unless condicao_atendida?(pergunta, respostas)

    pergunta.obrigatoria == "abertura" || (pergunta.obrigatoria == "encerramento" && encerrada)
  end

  def rotulo(pergunta, codigo)
    pergunta.opcoes.find { |opcao| opcao.codigo == codigo.to_s }&.rotulo || codigo.to_s
  end

  # Resposta pronta para leitura (rótulos no lugar dos códigos, data em dd/mm/aaaa)
  def resposta_formatada(pergunta, valor)
    case pergunta.tipo
    when "unica" then rotulo(pergunta, valor)
    when "multipla" then Array(valor).map { |codigo| rotulo(pergunta, codigo) }.join("; ")
    when "data" then data_valida(valor)&.strftime("%d/%m/%Y") || valor.to_s
    else valor.to_s
    end
  end

  private

  def construir_pergunta(atributos)
    tipo = atributos.fetch("tipo")
    exclusivas = Array(atributos["exclusivas"]).map(&:to_s)
    Pergunta.new(
      numero: atributos["numero"],
      chave: atributos.fetch("chave"),
      texto: atributos.fetch("texto"),
      tipo:,
      opcoes: atributos.fetch("opcoes", {}).map do |codigo, rotulo|
        Opcao.new(codigo: codigo.to_s, rotulo:, exclusiva: exclusivas.include?(codigo.to_s))
      end,
      obrigatoria: atributos["obrigatoria"],
      condicao: atributos["condicao"],
      paciente: atributos.fetch("paciente", false),
      ajuda: atributos["ajuda"],
      minimo: atributos.fetch("minimo", 0),
      maximo: atributos.fetch("maximo", tipo == "texto" ? 200 : 100_000),
      nao_maior_que: atributos["nao_maior_que"],
      nao_antes_de: atributos["nao_antes_de"]
    )
  end

  def normalizar_valor(pergunta, valor)
    case pergunta.tipo
    when "multipla" then Array(valor).map { |item| item.to_s.strip }.compact_blank.uniq.presence
    when "numero"
      texto = valor.to_s.strip
      texto.match?(/\A\d+\z/) ? texto.to_i : texto.presence
    else valor.to_s.squish.presence
    end
  end

  def validar_valor(pergunta, valor, respostas, mensagens)
    case pergunta.tipo
    when "texto"
      mensagens << "tem mais de #{pergunta.maximo} caracteres" if valor.to_s.length > pergunta.maximo
    when "numero"
      return mensagens << "deve ser um número inteiro" unless valor.is_a?(Integer)

      mensagens << "deve ser no mínimo #{pergunta.minimo}" if valor < pergunta.minimo
      mensagens << "deve ser no máximo #{pergunta.maximo}" if valor > pergunta.maximo
      limite = pergunta.nao_maior_que && respostas[pergunta.nao_maior_que]
      mensagens << "não pode ser maior que “#{self.pergunta(pergunta.nao_maior_que).texto}”" if limite.is_a?(Integer) && valor > limite
    when "data"
      return mensagens << "não é uma data válida" unless (data = data_valida(valor))

      mensagens << "não pode ser no futuro" if data > Date.current
      inicio = pergunta.nao_antes_de && data_valida(respostas[pergunta.nao_antes_de])
      mensagens << "não pode ser antes de “#{self.pergunta(pergunta.nao_antes_de).texto}”" if inicio && data < inicio
    when "unica"
      mensagens << "tem uma opção inválida" unless pergunta.opcoes.map(&:codigo).include?(valor)
    when "multipla"
      return mensagens << "tem uma opção inválida" unless valor.is_a?(Array) && (valor - pergunta.opcoes.map(&:codigo)).empty?

      exclusiva = pergunta.opcoes.find { |opcao| opcao.exclusiva && valor.include?(opcao.codigo) }
      mensagens << "“#{exclusiva.rotulo}” não pode ser marcada junto com outras opções" if exclusiva && valor.size > 1
    end
  end

  def mensagem_de_obrigatoria(pergunta)
    pergunta.obrigatoria == "encerramento" ? "é obrigatória para encerrar a notificação" : "é obrigatória"
  end

  def secao_de(pergunta)
    secoes.find { |candidata| candidata.perguntas.include?(pergunta) }
  end

  def data_valida(valor)
    Date.iso8601(valor) if valor.is_a?(String) && valor.match?(/\A\d{4}-\d{2}-\d{2}\z/)
  rescue Date::Error
    nil
  end

  # Erros de definição aparecem ao carregar o YAML (e nos testes), não no uso
  def conferir_definicao!
    chaves = perguntas.map(&:chave)
    falha = ->(mensagem) { raise DefinicaoInvalida, "#{chave}: #{mensagem}" }

    falha.("chaves repetidas") if chaves.uniq.size != chaves.size
    perguntas.each do |pergunta|
      falha.("chave inválida #{pergunta.chave}") unless pergunta.chave.match?(NOME_DE_CAMPO)
      falha.("tipo inválido em #{pergunta.chave}") unless TIPOS.include?(pergunta.tipo)
      falha.("obrigatoria inválida em #{pergunta.chave}") unless OBRIGATORIEDADES.include?(pergunta.obrigatoria)
      falha.("#{pergunta.chave} precisa de opções") if pergunta.tipo.in?(%w[unica multipla]) && pergunta.opcoes.empty?
      falha.("#{pergunta.chave} não é um campo do paciente") if pergunta.paciente && !CAMPOS_DO_PACIENTE.include?(pergunta.chave)
      conferir_referencia!(falha, pergunta, pergunta.nao_maior_que, "numero")
      conferir_referencia!(falha, pergunta, pergunta.nao_antes_de, "data")
      conferir_condicao!(falha, pergunta) if pergunta.condicao
    end
    falha.("encerramento deve apontar para uma pergunta de data") if campo_encerramento && pergunta(campo_encerramento)&.tipo != "data"
    falha.("lista com pergunta inexistente") if perguntas_da_lista.any?(&:nil?)
  end

  def conferir_referencia!(falha, pergunta, referencia, tipo)
    return unless referencia

    falha.("#{pergunta.chave} referencia #{referencia}, que não é do tipo #{tipo}") if self.pergunta(referencia)&.tipo != tipo
  end

  # A condição precisa apontar para a pergunta imediatamente anterior, de
  # escolha única: é assim que o CSS consegue mostrar e esconder sem JavaScript
  def conferir_condicao!(falha, pergunta)
    secao = secao_de(pergunta)
    anterior = secao.perguntas[secao.perguntas.index(pergunta) - 1] unless secao.perguntas.first == pergunta
    controladora = pergunta.condicao["pergunta"]
    unless anterior&.chave == controladora && anterior.tipo == "unica"
      falha.("a condição de #{pergunta.chave} deve depender da pergunta anterior, de escolha única")
    end
    invalidos = Array(pergunta.condicao["valores"]) - anterior.opcoes.map(&:codigo)
    falha.("a condição de #{pergunta.chave} usa códigos inexistentes: #{invalidos.join(', ')}") if invalidos.any?
  end
end
