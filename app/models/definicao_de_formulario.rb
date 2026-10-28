# Definição de um formulário clínico: seções, perguntas, opções (com os
# códigos originais), condições e regras de preenchimento. É o que o gerador
# de formulários (Configurações > Gerador de formulários) monta e o que cada
# versão de um formulário guarda (VersaoFormulario#estrutura, em JSON).
#
# Esta classe é a única porta de entrada de uma definição. Ela confere tudo o
# que vem na estrutura e recusa o resto: só campos conhecidos, cada um com o
# tipo certo, textos limpos e com tamanho máximo, quantidades limitadas e
# referências que existem. Uma definição que não passa aqui não é gravada nem
# mostrada. Para as respostas, ela define:
#   - quais chaves existem (strong params, parametros_permitidos);
#   - como normalizar o que chega do navegador (normalizar);
#   - o que é válido: tipos, opções, obrigatórias, comparações e condições (validar).
#
# Uma pergunta com condição só vale (e só aparece) quando a pergunta de escolha
# de que ela depende tem uma das opções da condição. Ela fica logo abaixo da
# pergunta que a controla, junto com as outras que dependem dela (as perguntas
# de uma seção estão em pré-ordem), e pode ter as próprias dependentes. É isso
# que deixa mostrar e esconder só com CSS, sem JavaScript (application.css).
#
# Formato e regras: docs/novo-formulario.md.
class DefinicaoDeFormulario
  TIPOS = {
    "texto" => "Texto curto",
    "texto_longo" => "Texto longo",
    "numero" => "Número",
    "data" => "Data",
    "unica" => "Escolha única",
    "lista_suspensa" => "Lista suspensa",
    "multipla" => "Múltipla escolha"
  }.freeze
  TIPOS_DE_ESCOLHA = %w[unica lista_suspensa multipla].freeze
  # abertura: sempre; encerramento: quando a pergunta de encerramento é preenchida
  OBRIGATORIEDADES = [ nil, "abertura", "encerramento" ].freeze
  # automatica: 1, 2, 3...; manual: o número de cada pergunta (ex.: o do formulário em papel)
  NUMERACOES = %w[automatica manual].freeze

  # Limites. Uma definição, mesmo montada de má-fé, nunca fica grande a ponto
  # de pesar no servidor nem na tela.
  MAXIMO_DE_SECOES = 30
  MAXIMO_DE_PERGUNTAS = 300
  MAXIMO_DE_OPCOES = 100
  MAXIMO_DE_OPCOES_NO_FORMULARIO = 3000
  MAXIMO_DE_DEPENDENTES = 10 # perguntas que dependem diretamente de uma (o CSS tem uma regra para cada)
  MAXIMO_DE_NIVEIS = 3       # condição dentro de condição
  MAXIMO_DE_COLUNAS = 3      # perguntas que viram colunas na lista de registros
  MAXIMO_DE_BYTES = 1_000_000
  TAMANHOS = {
    titulo: 150, descricao: 500, finalidade: 1000, base_legal: 1000, titulo_da_secao: 150, descricao_da_secao: 500,
    texto: 500, ajuda: 500, rotulo: 200
  }.freeze
  # Limite de caracteres das respostas de texto (faixa aceita e padrão)
  CARACTERES = { "texto" => 1..200, "texto_longo" => 1..5000 }.freeze
  CARACTERES_PADRAO = { "texto" => 100, "texto_longo" => 1000 }.freeze
  NUMERO_ABSOLUTO = 1_000_000_000
  DECIMAIS = 0..3
  MINIMO_PADRAO = 0
  MAXIMO_PADRAO = 100_000
  DATAS = Date.new(1900, 1, 1)..Date.new(2199, 12, 31)

  # Chaves geradas pelo servidor; códigos e números digitados pelo admin
  CHAVE = /\A[a-z][a-z0-9_]{0,63}\z/
  CODIGO = /\A[0-9A-Za-z][0-9A-Za-z_.-]{0,15}\z/
  NUMERO = /\A[0-9A-Za-z][0-9A-Za-z.-]{0,9}\z/
  ID_DA_SECAO = /\As[1-9][0-9]{0,3}\z/
  # Nomes usados pelo próprio sistema: uma pergunta nunca se chama assim
  CHAVES_RESERVADAS = %w[
    base id setor setor_id paciente paciente_id user user_id formulario versao_formulario versao_formulario_id
    dados_formulario lock_version finalidade base_legal created_at updated_at prontuario_sah prontuario_aghuse iniciais
  ].freeze

  CAMPOS_DO_FORMULARIO = %w[titulo descricao finalidade base_legal numeracao encerramento lista secoes].freeze
  CAMPOS_DA_SECAO = %w[id titulo descricao perguntas].freeze
  CAMPOS_DA_PERGUNTA = %w[chave numero texto tipo ajuda obrigatoria condicao].freeze
  CAMPOS_DO_TIPO = {
    "texto" => %w[maximo],
    "texto_longo" => %w[maximo],
    "numero" => %w[minimo maximo decimais nao_maior_que],
    "data" => %w[nao_antes_de permite_futuro],
    "unica" => %w[opcoes],
    "lista_suspensa" => %w[opcoes],
    "multipla" => %w[opcoes]
  }.freeze
  CAMPOS_DA_OPCAO = %w[codigo rotulo exclusiva].freeze
  CAMPOS_DA_CONDICAO = %w[pergunta valores].freeze

  # Erro de definição: onde (:formulario, o id de uma seção ou a chave de uma
  # pergunta) e a mensagem, pronta para a tela do gerador
  Erro = Data.define(:onde, :mensagem)

  class DefinicaoInvalida < StandardError
    attr_reader :erros

    def initialize(erros)
      @erros = erros.freeze
      super(erros.map(&:mensagem).join(" "))
    end
  end

  Opcao = Data.define(:codigo, :rotulo, :exclusiva)
  Condicao = Data.define(:pergunta, :valores)
  Secao = Data.define(:id, :titulo, :descricao, :perguntas)
  # numero: o mostrado na tela (texto); profundidade: 0 sem condição, 1 se
  # depende de uma pergunta sem condição, e assim por diante
  Pergunta = Data.define(:chave, :numero, :texto, :tipo, :ajuda, :obrigatoria, :opcoes, :minimo, :maximo, :decimais,
                         :nao_maior_que, :nao_antes_de, :permite_futuro, :condicao, :secao_id, :profundidade) do
    def escolha? = TIPOS_DE_ESCOLHA.include?(tipo)
    def codigos = opcoes.map(&:codigo)
    def nome_do_tipo = TIPOS.fetch(tipo)
  end

  attr_reader :titulo, :descricao, :finalidade, :base_legal, :numeracao, :campo_encerramento, :secoes, :perguntas, :estrutura

  # estrutura: o Hash da definição (do JSON gravado ou do gerador). Com
  # rascunho: true, aceita o que ainda falta para publicar (finalidade, base
  # legal, seções e perguntas); todo o resto é conferido do mesmo jeito.
  # Levanta DefinicaoInvalida com todos os erros encontrados.
  def initialize(estrutura, rascunho: false)
    leitura = Leitura.new(estrutura, rascunho:)
    raise DefinicaoInvalida, leitura.erros if leitura.erros.any?

    @rascunho = rascunho
    @titulo, @descricao, @finalidade, @base_legal, @numeracao, @campo_encerramento, @chaves_da_lista =
      leitura.cabecalho.values_at("titulo", "descricao", "finalidade", "base_legal", "numeracao", "encerramento", "lista")
    @secoes = leitura.secoes
    @perguntas = @secoes.flat_map(&:perguntas).freeze
    @por_chave = @perguntas.index_by(&:chave).freeze
    @dependentes = @perguntas.select(&:condicao).group_by { |pergunta| pergunta.condicao.pergunta }.each_value(&:freeze).freeze
    @estrutura = leitura.estrutura
    freeze
  end

  def rascunho? = @rascunho

  def pergunta(chave)
    @por_chave[chave.to_s]
  end

  def chaves = @por_chave.keys

  # Perguntas mostradas como colunas na lista de registros
  def perguntas_da_lista
    @chaves_da_lista.map { |chave| pergunta(chave) }
  end

  # Perguntas que dependem diretamente desta, na ordem do formulário
  def dependentes(pergunta)
    @dependentes.fetch(pergunta.chave, [])
  end

  # A pergunta de que esta depende (nil se ela não tem condição)
  def controladora(pergunta)
    pergunta.condicao && pergunta(pergunta.condicao.pergunta)
  end

  # Perguntas sem condição de uma seção: as outras ficam dentro delas na tela
  def raizes(secao)
    secao.perguntas.reject(&:condicao)
  end

  # Posições (a partir de 1) dos dependentes que uma opção revela; o CSS mostra
  # o dependente dessa posição quando a opção está marcada
  def revelados_por(pergunta, codigo)
    dependentes(pergunta).each_with_index.filter_map { |dependente, indice| indice + 1 if dependente.condicao.valores.include?(codigo) }
  end

  # Strong params: só as chaves declaradas; múltipla escolha chega como lista
  def parametros_permitidos
    perguntas.map { |pergunta| pergunta.tipo == "multipla" ? { pergunta.chave => [] } : pergunta.chave }
  end

  def encerrada?(respostas)
    campo_encerramento.present? && respostas.is_a?(Hash) && respostas[campo_encerramento].present?
  end

  # A pergunta vale com estas respostas: não tem condição, ou a condição está
  # atendida e a pergunta de que ela depende também vale
  def visivel?(pergunta, respostas)
    return true unless pergunta.condicao
    return false unless respostas.is_a?(Hash)

    pai = controladora(pergunta)
    visivel?(pai, respostas) && marcou?(pai, respostas[pai.chave], pergunta.condicao.valores)
  end

  # Converte a entrada (parâmetros do navegador ou JSON salvo) para o formato
  # gravado: textos limpos, números convertidos, listas sem vazios. Perguntas em
  # branco ou fora da condição somem; as perguntas são percorridas em
  # pré-ordem, então a resposta de uma dependente some junto com a da pergunta
  # de que ela depende. Chaves desconhecidas e valores com formato errado são
  # mantidos para a validação recusá-los.
  def normalizar(entrada)
    return entrada unless entrada.is_a?(Hash)

    entrada = entrada.to_h.stringify_keys
    respostas = entrada.except(*chaves)
    perguntas.each do |pergunta|
      next unless visivel?(pergunta, respostas)

      valor = normalizar_valor(pergunta, entrada[pergunta.chave])
      respostas[pergunta.chave] = valor unless valor.nil?
    end
    respostas
  end

  # Erros por pergunta ({ "chave" => ["mensagem"] }). Erros gerais ficam em "base".
  def validar(respostas)
    return { "base" => [ "As respostas devem ser um conjunto de campos." ] } unless respostas.is_a?(Hash)

    respostas = respostas.to_h.stringify_keys
    erros = Hash.new { |hash, chave| hash[chave] = [] }
    desconhecidas = respostas.keys - chaves
    if desconhecidas.any?
      erros["base"] << "Campos desconhecidos: #{desconhecidas.first(5).map { |chave| chave.truncate(40) }.join(', ')}."
    end

    encerrada = encerrada?(respostas)
    perguntas.each do |pergunta|
      valor = respostas[pergunta.chave]
      if !visivel?(pergunta, respostas)
        erros[pergunta.chave] << "não se aplica com a resposta dada a “#{controladora(pergunta).texto}”" unless vazio?(valor)
      elsif vazio?(valor)
        erros[pergunta.chave] << mensagem_de_obrigatoria(pergunta) if obrigatoria?(pergunta, encerrada)
      else
        validar_valor(pergunta, valor, respostas, erros[pergunta.chave])
      end
    end
    erros.reject { |_, mensagens| mensagens.empty? }
  end

  def obrigatoria?(pergunta, encerrada)
    pergunta.obrigatoria == "abertura" || (pergunta.obrigatoria == "encerramento" && encerrada)
  end

  def rotulo(pergunta, codigo)
    pergunta.opcoes.find { |opcao| opcao.codigo == codigo.to_s }&.rotulo || codigo.to_s
  end

  # Resposta pronta para leitura: rótulos no lugar dos códigos, data em
  # dd/mm/aaaa e decimal com vírgula
  def resposta_formatada(pergunta, valor)
    case pergunta.tipo
    when "unica", "lista_suspensa" then rotulo(pergunta, valor)
    when "multipla" then Array(valor).map { |codigo| rotulo(pergunta, codigo) }.join("; ")
    when "data" then data_valida(valor)&.strftime("%d/%m/%Y") || valor.to_s
    when "numero" then valor.to_s.tr(".", ",")
    else valor.to_s
    end
  end

  private

  def vazio?(valor)
    valor.nil? || (valor.respond_to?(:empty?) && valor.empty?)
  end

  def marcou?(pergunta, valor, codigos)
    if pergunta.tipo == "multipla"
      valor.is_a?(Array) && valor.intersect?(codigos)
    else
      codigos.include?(valor)
    end
  end

  def normalizar_valor(pergunta, valor)
    case pergunta.tipo
    when "multipla"
      return valor unless valor.nil? || valor.is_a?(Array) || escalar?(valor)

      Array(valor).map { |item| escalar?(item) ? TextoSeguro.linha(item) : item }.reject { |item| item.nil? || item == "" }.uniq.presence
    when "numero" then normalizar_numero(pergunta, valor)
    when "texto_longo" then escalar?(valor) ? TextoSeguro.paragrafo(valor).presence : valor
    else escalar?(valor) ? TextoSeguro.linha(valor).presence : valor
    end
  end

  def escalar?(valor)
    valor.is_a?(String) || valor.is_a?(Integer)
  end

  # Inteiro vira Integer; decimal vira texto canônico ("72.5"), sem a
  # imprecisão do ponto flutuante. Aceita vírgula ou ponto.
  def normalizar_numero(pergunta, valor)
    return valor unless escalar?(valor)

    texto = TextoSeguro.linha(valor).delete(" ")
    return nil if texto.empty?

    if pergunta.decimais.zero?
      texto.match?(/\A-?\d{1,15}\z/) ? Integer(texto, 10) : texto
    elsif texto.match?(/\A-?\d{1,15}(?:[.,]\d{1,15})?\z/)
      decimal_canonico(BigDecimal(texto.tr(",", ".")))
    else
      texto
    end
  end

  def decimal_canonico(numero)
    return "0" if numero.zero?

    numero.to_s("F").sub(/\.0\z/, "")
  end

  # O número de uma resposta já normalizada (Integer ou BigDecimal), ou nil se
  # o formato não é o de um número desta pergunta
  def numero_de(pergunta, valor)
    if pergunta.decimais.zero?
      valor if valor.is_a?(Integer)
    elsif valor.is_a?(String) && valor.match?(/\A-?\d{1,15}(?:\.\d{1,15})?\z/)
      BigDecimal(valor)
    end
  end

  def validar_valor(pergunta, valor, respostas, mensagens)
    case pergunta.tipo
    when "texto", "texto_longo"
      return mensagens << "tem um formato inválido" unless valor.is_a?(String)

      mensagens << "tem mais de #{pergunta.maximo} caracteres" if valor.length > pergunta.maximo
    when "numero" then validar_numero(pergunta, valor, respostas, mensagens)
    when "data" then validar_data(pergunta, valor, respostas, mensagens)
    when "unica", "lista_suspensa"
      mensagens << "tem uma opção inválida" unless valor.is_a?(String) && pergunta.codigos.include?(valor)
    when "multipla"
      return mensagens << "tem uma opção inválida" unless valor.is_a?(Array) && valor.all?(String) && (valor - pergunta.codigos).empty?

      exclusiva = pergunta.opcoes.find { |opcao| opcao.exclusiva && valor.include?(opcao.codigo) }
      mensagens << "“#{exclusiva.rotulo}” não pode ser marcada junto com outras opções" if exclusiva && valor.size > 1
    end
  end

  def validar_numero(pergunta, valor, respostas, mensagens)
    numero = numero_de(pergunta, valor)
    return mensagens << (pergunta.decimais.zero? ? "deve ser um número inteiro" : "deve ser um número") if numero.nil?

    casas = valor.to_s[/\.(\d+)\z/, 1].to_s.length
    mensagens << "deve ter no máximo #{pergunta.decimais} casas decimais" if casas > pergunta.decimais
    mensagens << "deve ser no mínimo #{pergunta.minimo}" if numero < pergunta.minimo
    mensagens << "deve ser no máximo #{pergunta.maximo}" if numero > pergunta.maximo

    referencia = pergunta.nao_maior_que && pergunta(pergunta.nao_maior_que)
    limite = referencia && visivel?(referencia, respostas) && numero_de(referencia, respostas[referencia.chave])
    mensagens << "não pode ser maior que “#{referencia.texto}”" if limite && numero > limite
  end

  def validar_data(pergunta, valor, respostas, mensagens)
    data = data_valida(valor)
    return mensagens << "não é uma data válida" unless data
    return mensagens << "deve estar entre #{DATAS.first.year} e #{DATAS.last.year}" unless DATAS.cover?(data)

    mensagens << "não pode ser no futuro" if !pergunta.permite_futuro && data > Date.current
    referencia = pergunta.nao_antes_de && pergunta(pergunta.nao_antes_de)
    inicio = referencia && visivel?(referencia, respostas) && data_valida(respostas[referencia.chave])
    mensagens << "não pode ser antes de “#{referencia.texto}”" if inicio && data < inicio
  end

  def mensagem_de_obrigatoria(pergunta)
    pergunta.obrigatoria == "encerramento" ? "é obrigatória para encerrar a notificação" : "é obrigatória"
  end

  def data_valida(valor)
    Date.iso8601(valor) if valor.is_a?(String) && valor.match?(/\A\d{4}-\d{2}-\d{2}\z/)
  rescue Date::Error
    nil
  end

  # Lê e confere uma estrutura campo a campo, juntando todos os erros (o gerador
  # mostra todos de uma vez). Monta, ao mesmo tempo, a estrutura canônica: só
  # os campos conhecidos, com os textos limpos e os valores padrão explícitos.
  # Só uma estrutura sem nenhum erro vira Secao e Pergunta.
  class Leitura
    attr_reader :erros, :cabecalho, :secoes, :estrutura

    def initialize(entrada, rascunho:)
      @rascunho = rascunho
      @erros = []
      ler(entrada)
    end

    private

    def ler(entrada)
      return erro(:formulario, "A definição do formulário precisa ser um conjunto de campos.") unless entrada.is_a?(Hash)
      return erro(:formulario, "A definição do formulário não pôde ser lida (formato inválido ou grande demais).") unless cabe?(entrada)

      campos_conhecidos(entrada, CAMPOS_DO_FORMULARIO, :formulario, "Formulário")
      @cabecalho = {
        "titulo" => linha(entrada["titulo"], :formulario, "Título do formulário", TAMANHOS[:titulo]),
        "descricao" => paragrafo(entrada["descricao"], :formulario, "Descrição do formulário", TAMANHOS[:descricao], obrigatorio: false),
        "finalidade" => paragrafo(entrada["finalidade"], :formulario, "Finalidade", TAMANHOS[:finalidade], obrigatorio: !@rascunho),
        "base_legal" => paragrafo(entrada["base_legal"], :formulario, "Base legal", TAMANHOS[:base_legal], obrigatorio: !@rascunho),
        "numeracao" => opcao_da_lista(entrada.fetch("numeracao", "automatica"), NUMERACOES, :formulario, "Numeração das perguntas"),
        "encerramento" => entrada["encerramento"],
        "lista" => entrada.fetch("lista", [])
      }

      secoes = lista(entrada["secoes"], :formulario, "Seções", MAXIMO_DE_SECOES)
      fichas = secoes.each_with_index.filter_map { |secao, indice| ler_secao(secao, indice) }
      # As regras entre as partes só olham uma estrutura em que cada campo já
      # passou: nunca trabalham sobre um valor de tipo errado
      return if @erros.any?

      conferir_conjunto(fichas)
      montar(fichas) if @erros.empty?
    end

    # --- Leitura de cada parte ---------------------------------------------

    def ler_secao(entrada, indice)
      nome = "Seção #{indice + 1}"
      return erro(:formulario, "#{nome}: precisa ser um conjunto de campos.") unless entrada.is_a?(Hash)

      id = entrada["id"]
      onde = id.is_a?(String) && id.match?(ID_DA_SECAO) ? id : :formulario
      erro(:formulario, "#{nome}: identificador inválido.") if onde == :formulario
      titulo = linha(entrada["titulo"], onde, "#{nome}, título", TAMANHOS[:titulo_da_secao])
      nome = "Seção “#{titulo}”" if titulo
      campos_conhecidos(entrada, CAMPOS_DA_SECAO, onde, nome)
      perguntas = lista(entrada["perguntas"], onde, "#{nome}, perguntas", MAXIMO_DE_PERGUNTAS)

      {
        "id" => id,
        "titulo" => titulo,
        "descricao" => paragrafo(entrada["descricao"], onde, "#{nome}, descrição", TAMANHOS[:descricao_da_secao], obrigatorio: false),
        "perguntas" => perguntas.each_with_index.filter_map { |pergunta, posicao| ler_pergunta(pergunta, nome, posicao) }
      }.compact
    end

    def ler_pergunta(entrada, nome_da_secao, posicao)
      nome = "#{nome_da_secao}, pergunta #{posicao + 1}"
      return erro(:formulario, "#{nome}: precisa ser um conjunto de campos.") unless entrada.is_a?(Hash)

      chave = entrada["chave"]
      onde = chave.is_a?(String) && chave.match?(CHAVE) ? chave : :formulario
      texto = linha(entrada["texto"], onde, "#{nome}, enunciado", TAMANHOS[:texto])
      nome = "Pergunta “#{texto.truncate(60)}”" if texto
      erro(onde, "#{nome}: chave inválida.") unless onde.is_a?(String)
      erro(onde, "#{nome}: a chave “#{chave}” é reservada pelo sistema.") if CHAVES_RESERVADAS.include?(chave)

      tipo = entrada["tipo"]
      return erro(onde, "#{nome}: tipo de pergunta desconhecido.") unless TIPOS.key?(tipo)

      campos_conhecidos(entrada, CAMPOS_DA_PERGUNTA + CAMPOS_DO_TIPO.fetch(tipo), onde, nome)
      pergunta = {
        "chave" => chave,
        "numero" => numero_da_pergunta(entrada["numero"], onde, nome),
        "texto" => texto,
        "tipo" => tipo,
        "ajuda" => paragrafo(entrada["ajuda"], onde, "#{nome}, texto de ajuda", TAMANHOS[:ajuda], obrigatorio: false),
        "obrigatoria" => opcao_da_lista(entrada["obrigatoria"], OBRIGATORIEDADES, onde, "#{nome}, obrigatoriedade"),
        "condicao" => ler_condicao(entrada["condicao"], onde, nome)
      }
      pergunta.merge!(ler_campos_do_tipo(entrada, tipo, onde, nome))
      pergunta.compact
    end

    def ler_campos_do_tipo(entrada, tipo, onde, nome)
      case tipo
      when "texto", "texto_longo"
        { "maximo" => inteiro(entrada["maximo"], CARACTERES.fetch(tipo), CARACTERES_PADRAO.fetch(tipo), onde, "#{nome}, limite de caracteres") }
      when "numero"
        faixa = -NUMERO_ABSOLUTO..NUMERO_ABSOLUTO
        minimo = inteiro(entrada["minimo"], faixa, MINIMO_PADRAO, onde, "#{nome}, valor mínimo")
        maximo = inteiro(entrada["maximo"], faixa, MAXIMO_PADRAO, onde, "#{nome}, valor máximo")
        erro(onde, "#{nome}: o valor mínimo não pode ser maior que o máximo.") if minimo && maximo && minimo > maximo
        { "minimo" => minimo, "maximo" => maximo,
          "decimais" => inteiro(entrada["decimais"], DECIMAIS, 0, onde, "#{nome}, casas decimais"),
          "nao_maior_que" => referencia(entrada["nao_maior_que"], onde, nome) }
      when "data"
        { "nao_antes_de" => referencia(entrada["nao_antes_de"], onde, nome),
          "permite_futuro" => booleano(entrada["permite_futuro"], onde, "#{nome}, data futura") }
      else
        { "opcoes" => ler_opcoes(entrada["opcoes"], tipo, onde, nome) }
      end
    end

    def ler_opcoes(entrada, tipo, onde, nome)
      opcoes = lista(entrada, onde, "#{nome}, opções", MAXIMO_DE_OPCOES)
      erro(onde, "#{nome}: precisa de pelo menos uma opção.") if opcoes.empty?

      lidas = opcoes.each_with_index.filter_map do |opcao, indice|
        rotulo_da_opcao = "#{nome}, opção #{indice + 1}"
        next erro(onde, "#{rotulo_da_opcao}: precisa ser um conjunto de campos.") unless opcao.is_a?(Hash)

        campos_conhecidos(opcao, CAMPOS_DA_OPCAO, onde, rotulo_da_opcao)
        codigo = opcao["codigo"]
        erro(onde, "#{rotulo_da_opcao}: código inválido (use até 16 letras, números, ponto, traço ou sublinhado).") unless codigo.is_a?(String) && codigo.match?(CODIGO)
        exclusiva = booleano(opcao["exclusiva"], onde, "#{rotulo_da_opcao}, exclusiva")
        erro(onde, "#{rotulo_da_opcao}: só a múltipla escolha tem opção exclusiva.") if exclusiva && tipo != "multipla"
        { "codigo" => codigo, "rotulo" => linha(opcao["rotulo"], onde, "#{rotulo_da_opcao}, rótulo", TAMANHOS[:rotulo]),
          "exclusiva" => (true if exclusiva) }.compact
      end

      codigos = lidas.map { |opcao| opcao["codigo"] }
      rotulos = lidas.filter_map { |opcao| opcao["rotulo"]&.downcase }
      erro(onde, "#{nome}: há códigos de opção repetidos.") if codigos.uniq.size != codigos.size
      erro(onde, "#{nome}: há opções com o mesmo rótulo.") if rotulos.uniq.size != rotulos.size
      lidas
    end

    def ler_condicao(entrada, onde, nome)
      return if entrada.nil?
      return erro(onde, "#{nome}: a condição precisa ser um conjunto de campos.") unless entrada.is_a?(Hash)

      campos_conhecidos(entrada, CAMPOS_DA_CONDICAO, onde, "#{nome}, condição")
      valores = lista(entrada["valores"], onde, "#{nome}, opções da condição", MAXIMO_DE_OPCOES)
      erro(onde, "#{nome}: escolha pelo menos uma opção que mostra esta pergunta.") if valores.empty?
      unless valores.all? { |valor| valor.is_a?(String) && valor.match?(CODIGO) } && valores.uniq.size == valores.size
        erro(onde, "#{nome}: a condição tem opções inválidas ou repetidas.")
      end
      { "pergunta" => referencia(entrada["pergunta"], onde, nome, obrigatoria: true), "valores" => valores }
    end

    def numero_da_pergunta(valor, onde, nome)
      return if valor.nil?
      return erro(onde, "#{nome}: número inválido (use até 10 letras, números, ponto ou traço).") unless valor.is_a?(String) && valor.match?(NUMERO)

      valor
    end

    # --- Regras entre as partes --------------------------------------------

    def conferir_conjunto(secoes)
      perguntas = secoes.flat_map { |secao| secao["perguntas"] }
      por_chave = perguntas.index_by { |pergunta| pergunta["chave"] }

      conferir_completo(secoes, perguntas)
      repetidos(secoes.map { |secao| secao["id"] }, "Há seções com o mesmo identificador.")
      repetidos(perguntas.map { |pergunta| pergunta["chave"] }, "Há perguntas com a mesma chave.")
      erro(:formulario, "O formulário passa de #{MAXIMO_DE_PERGUNTAS} perguntas.") if perguntas.size > MAXIMO_DE_PERGUNTAS
      if perguntas.sum { |pergunta| pergunta.fetch("opcoes", []).size } > MAXIMO_DE_OPCOES_NO_FORMULARIO
        erro(:formulario, "O formulário passa de #{MAXIMO_DE_OPCOES_NO_FORMULARIO} opções no total.")
      end

      conferir_numeracao(perguntas)
      secoes.each { |secao| conferir_condicoes(secao, por_chave) }
      perguntas.each { |pergunta| conferir_referencias(pergunta, por_chave) }
      conferir_encerramento(perguntas, por_chave)
      conferir_lista(por_chave)
    end

    # O que falta para publicar; o rascunho pode ainda não ter
    def conferir_completo(secoes, perguntas)
      return if @rascunho

      erro(:formulario, "O formulário precisa de pelo menos uma pergunta.") if perguntas.empty?
      secoes.each do |secao|
        erro(secao["id"], "Seção “#{secao["titulo"]}”: não tem perguntas.") if secao["perguntas"].empty?
      end
    end

    def conferir_numeracao(perguntas)
      if @cabecalho["numeracao"] == "manual"
        perguntas.each { |pergunta| erro(pergunta["chave"], "#{nome(pergunta)}: falta o número.") unless pergunta["numero"] }
        repetidos(perguntas.filter_map { |pergunta| pergunta["numero"] }, "Há perguntas com o mesmo número.")
      else
        perguntas.each do |pergunta|
          erro(pergunta["chave"], "#{nome(pergunta)}: com a numeração automática, a pergunta não tem número próprio.") if pergunta["numero"]
        end
      end
    end

    # Pré-ordem: cada pergunta com condição vem depois da pergunta de escolha de
    # que depende, na mesma seção, e entre as duas só há perguntas que também
    # dependem dela (direta ou indiretamente). A pilha guarda a linha de
    # perguntas "abertas" acima da posição atual.
    def conferir_condicoes(secao, por_chave)
      pilha = []
      contagem = Hash.new(0)
      secao["perguntas"].each do |pergunta|
        condicao = pergunta["condicao"]
        unless condicao
          pilha = [ pergunta ]
          next
        end

        pai = por_chave[condicao["pergunta"]]
        posicao = pilha.rindex { |aberta| aberta["chave"] == condicao["pergunta"] }
        if pai.nil? || posicao.nil?
          erro(pergunta["chave"], "#{nome(pergunta)}: a condição precisa depender de uma pergunta de escolha logo acima dela, " \
                                  "na mesma seção (só outras perguntas que dependem da mesma podem ficar entre as duas).")
          pilha = [ pergunta ]
          next
        end

        pilha = pilha.first(posicao + 1) << pergunta
        contagem[pai["chave"]] += 1
        conferir_condicao(pergunta, pai, pilha.size - 1, contagem[pai["chave"]])
      end
    end

    def conferir_condicao(pergunta, pai, profundidade, dependentes)
      unless TIPOS_DE_ESCOLHA.include?(pai["tipo"])
        return erro(pergunta["chave"], "#{nome(pergunta)}: só uma pergunta de escolha (única, lista ou múltipla) controla outras.")
      end

      inexistentes = pergunta["condicao"]["valores"] - pai.fetch("opcoes", []).map { |opcao| opcao["codigo"] }
      erro(pergunta["chave"], "#{nome(pergunta)}: a condição usa opções que “#{pai["texto"]}” não tem.") if inexistentes.any?
      erro(pergunta["chave"], "#{nome(pergunta)}: passa de #{MAXIMO_DE_NIVEIS} níveis de condição.") if profundidade > MAXIMO_DE_NIVEIS
      if dependentes > MAXIMO_DE_DEPENDENTES
        erro(pai["chave"], "#{nome(pai)}: no máximo #{MAXIMO_DE_DEPENDENTES} perguntas podem depender dela.")
      end
    end

    def conferir_referencias(pergunta, por_chave)
      { "nao_maior_que" => "numero", "nao_antes_de" => "data" }.each do |campo, tipo|
        referencia = pergunta[campo] or next

        alvo = por_chave[referencia]
        if referencia == pergunta["chave"] || alvo.nil? || alvo["tipo"] != tipo
          erro(pergunta["chave"], "#{nome(pergunta)}: a comparação precisa apontar para outra pergunta de #{TIPOS.fetch(tipo).downcase}.")
        end
      end
    end

    # A pergunta de encerramento "fecha" o registro: uma data sem condição, que
    # não pode ser no futuro nem obrigatória (senão todo registro nasceria encerrado)
    def conferir_encerramento(perguntas, por_chave)
      campo = @cabecalho["encerramento"]
      if campo.nil?
        perguntas.each do |pergunta|
          next unless pergunta["obrigatoria"] == "encerramento"

          erro(pergunta["chave"], "#{nome(pergunta)}: “obrigatória para encerrar” precisa de uma pergunta de encerramento no formulário.")
        end
        return
      end

      alvo = campo.is_a?(String) && por_chave[campo]
      if !alvo || alvo["tipo"] != "data" || alvo["condicao"] || alvo["permite_futuro"] || alvo["obrigatoria"]
        erro(:formulario, "A pergunta de encerramento precisa ser uma data sem condição, que não aceita data futura e não é obrigatória.")
      end
    end

    def conferir_lista(por_chave)
      lista = @cabecalho["lista"]
      unless lista.is_a?(Array) && lista.size <= MAXIMO_DE_COLUNAS && lista.uniq.size == lista.size &&
             lista.all? { |chave| chave.is_a?(String) && por_chave[chave] && por_chave[chave]["tipo"] != "texto_longo" }
        erro(:formulario, "As colunas da lista precisam ser até #{MAXIMO_DE_COLUNAS} perguntas diferentes do formulário, sem texto longo.")
      end
    end

    # --- Montagem (só sem erros) -------------------------------------------

    def montar(fichas)
      contador = 0
      manual = @cabecalho["numeracao"] == "manual"
      profundidades = {}
      @secoes = fichas.map do |secao|
        perguntas = secao["perguntas"].map do |pergunta|
          condicao = pergunta["condicao"]
          profundidades[pergunta["chave"]] = condicao ? profundidades.fetch(condicao["pergunta"]) + 1 : 0
          Pergunta.new(
            chave: pergunta["chave"], numero: manual ? pergunta["numero"] : (contador += 1).to_s, texto: pergunta["texto"],
            tipo: pergunta["tipo"], ajuda: pergunta["ajuda"], obrigatoria: pergunta["obrigatoria"],
            opcoes: pergunta.fetch("opcoes", []).map { |opcao| Opcao.new(codigo: opcao["codigo"], rotulo: opcao["rotulo"], exclusiva: opcao.fetch("exclusiva", false)) }.freeze,
            minimo: pergunta["minimo"], maximo: pergunta["maximo"], decimais: pergunta["decimais"],
            nao_maior_que: pergunta["nao_maior_que"], nao_antes_de: pergunta["nao_antes_de"],
            permite_futuro: pergunta["permite_futuro"],
            condicao: condicao && Condicao.new(pergunta: condicao["pergunta"], valores: condicao["valores"].freeze),
            secao_id: secao["id"], profundidade: profundidades.fetch(pergunta["chave"])
          )
        end
        Secao.new(id: secao["id"], titulo: secao["titulo"], descricao: secao["descricao"], perguntas: perguntas.freeze)
      end.freeze
      @estrutura = @cabecalho.compact.merge("secoes" => fichas).then { |estrutura| congelar(estrutura) }
    end

    # --- Ferramentas -------------------------------------------------------

    def erro(onde, mensagem)
      @erros << Erro.new(onde:, mensagem:)
      nil
    end

    def nome(pergunta)
      "Pergunta “#{pergunta["texto"].truncate(60)}”"
    end

    def cabe?(entrada)
      JSON.generate(entrada).bytesize <= MAXIMO_DE_BYTES
    rescue JSON::JSONError, Encoding::UndefinedConversionError
      false
    end

    def campos_conhecidos(entrada, permitidos, onde, nome)
      desconhecidos = entrada.keys - permitidos
      erro(onde, "#{nome}: campos desconhecidos (#{desconhecidos.first(5).map { |campo| campo.to_s.truncate(30) }.join(', ')}).") if desconhecidos.any?
    end

    def repetidos(valores, mensagem)
      erro(:formulario, mensagem) if valores.compact.uniq.size != valores.compact.size
    end

    def lista(valor, onde, nome, maximo)
      return [] if valor.nil? && @rascunho
      return erro(onde, "#{nome}: precisa ser uma lista.") || [] unless valor.is_a?(Array)
      return erro(onde, "#{nome}: no máximo #{maximo}.") || [] if valor.size > maximo

      valor
    end

    def linha(valor, onde, nome, maximo, obrigatorio: true)
      texto(valor, onde, nome, maximo, obrigatorio) { |bruto| TextoSeguro.linha(bruto) }
    end

    def paragrafo(valor, onde, nome, maximo, obrigatorio: true)
      texto(valor, onde, nome, maximo, obrigatorio) { |bruto| TextoSeguro.paragrafo(bruto) }
    end

    def texto(valor, onde, nome, maximo, obrigatorio)
      return erro(onde, "#{nome}: precisa ser um texto.") unless valor.nil? || valor.is_a?(String)

      limpo = yield(valor.to_s)
      return erro(onde, "#{nome}: falta preencher.") if limpo.empty? && obrigatorio
      return erro(onde, "#{nome}: no máximo #{maximo} caracteres.") if limpo.length > maximo

      limpo.presence
    end

    def inteiro(valor, faixa, padrao, onde, nome)
      return padrao if valor.nil?
      return erro(onde, "#{nome}: precisa ser um número inteiro de #{faixa.min} a #{faixa.max}.") unless valor.is_a?(Integer) && faixa.cover?(valor)

      valor
    end

    def booleano(valor, onde, nome)
      return false if valor.nil?
      return erro(onde, "#{nome}: precisa ser sim ou não.") unless valor == true || valor == false

      valor
    end

    def opcao_da_lista(valor, permitidos, onde, nome)
      return erro(onde, "#{nome}: valor desconhecido.") unless permitidos.include?(valor)

      valor
    end

    def referencia(valor, onde, nome, obrigatoria: false)
      return erro(onde, "#{nome}: falta a pergunta de referência.") if valor.nil? && obrigatoria
      return if valor.nil?
      return erro(onde, "#{nome}: referência inválida.") unless valor.is_a?(String) && valor.match?(CHAVE)

      valor
    end

    def congelar(objeto)
      case objeto
      when Hash then objeto.transform_values { |valor| congelar(valor) }.freeze
      when Array then objeto.map { |valor| congelar(valor) }.freeze
      when String then objeto.dup.freeze
      else objeto
      end
    end
  end
  private_constant :Leitura
end
