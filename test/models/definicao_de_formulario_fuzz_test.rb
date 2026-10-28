require "test_helper"

# Teste com dados aleatórios do motor de formulários: definições válidas de
# todos os tipos, com condições em até três níveis, respostas válidas, lixo e
# definições estragadas de propósito. As regras: definição válida é aceita e
# volta igual pelo JSON; resposta válida passa; nada, nem o lixo, levanta
# outra exceção que não a DefinicaoInvalida. A semente sai na mensagem de
# falha; para repetir: SEMENTE_DO_MOTOR=123 bin/rails test este_arquivo.
class DefinicaoDeFormularioFuzzTest < ActiveSupport::TestCase
  TIPOS = DefinicaoDeFormulario::TIPOS.keys.freeze
  LIXO = [
    nil, "", " ", "‮​", "x" * 6000, "<script>alert(1)</script>", "1e9", "-0", "0x1F", "2020-02-30", "9999-12-31",
    "1,5", "1.555", 12, -3, 1.5, Float::NAN, true, [], [ "" ], [ nil ], [ [ "1" ] ], [ { "a" => "1" } ], { "a" => "1" }, :simbolo,
    "\xFF".dup.force_encoding("BINARY"), "1\u0000", "1" * 20
  ].freeze

  setup do
    @semente = Integer(ENV.fetch("SEMENTE_DO_MOTOR", Random.new_seed % 1_000_000))
    @sorteio = Random.new(@semente)
  end

  test "definições válidas aleatórias são aceitas e voltam iguais pelo JSON" do
    150.times do |vez|
      estrutura = definicao_aleatoria
      definicao = carregar(estrutura, "definição #{vez}")

      assert_equal definicao.estrutura, DefinicaoDeFormulario.new(JSON.parse(definicao.estrutura.to_json)).estrutura, mensagem(vez)
      assert_equal definicao.chaves.uniq, definicao.chaves, mensagem(vez)
      definicao.perguntas.select(&:condicao).each do |pergunta|
        assert_includes definicao.dependentes(definicao.controladora(pergunta)), pergunta, mensagem(vez)
        assert_operator pergunta.profundidade, :<=, DefinicaoDeFormulario::MAXIMO_DE_NIVEIS, mensagem(vez)
      end
    end
  end

  test "respostas válidas passam, e normalizar duas vezes dá o mesmo resultado" do
    100.times do |vez|
      definicao = carregar(definicao_aleatoria, "definição #{vez}")
      5.times do
        respostas = definicao.normalizar(respostas_validas(definicao))

        assert_equal({}, definicao.validar(respostas), mensagem(vez, respostas))
        assert_equal respostas, definicao.normalizar(respostas), mensagem(vez, respostas)
        # Só ficam respostas de perguntas que estão à mostra
        respostas.each_key { |chave| assert definicao.visivel?(definicao.pergunta(chave), respostas), mensagem(vez, chave) }
      end
    end
  end

  test "lixo nas respostas vira erro de validação, nunca exceção" do
    60.times do |vez|
      definicao = carregar(definicao_aleatoria, "definição #{vez}")
      10.times do
        entrada = definicao.chaves.sample(@sorteio.rand(1..5), random: @sorteio).to_h { |chave| [ chave, LIXO.sample(random: @sorteio) ] }
        entrada["campo_inventado_#{@sorteio.rand(100)}"] = LIXO.sample(random: @sorteio) if @sorteio.rand < 0.3

        erros = begin
          definicao.validar(definicao.normalizar(entrada))
        rescue StandardError => e
          flunk "#{mensagem(vez, entrada.transform_values { |valor| valor.inspect[0, 30] })} levantou #{e.class}: #{e.message}"
        end
        assert_kind_of Hash, erros
        erros.each do |chave, mensagens|
          assert chave == "base" || definicao.pergunta(chave), mensagem(vez, chave)
          assert mensagens.all?(String), mensagem(vez, mensagens)
        end
      end
    end
  end

  test "definições estragadas de propósito são recusadas com DefinicaoInvalida, e só com ela" do
    300.times do |vez|
      estrutura = estragar(definicao_aleatoria)
      begin
        DefinicaoDeFormulario.new(estrutura)
      rescue DefinicaoDeFormulario::DefinicaoInvalida => e
        assert e.erros.all? { |erro| erro.mensagem.is_a?(String) && erro.mensagem.present? }, mensagem(vez)
      rescue StandardError => e
        flunk "#{mensagem(vez)}: levantou #{e.class}: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      end
    end
  end

  private

  def mensagem(vez, *extra)
    "semente #{@semente}, vez #{vez} #{extra.map(&:inspect).join(' ')[0, 300]}"
  end

  def carregar(estrutura, contexto)
    DefinicaoDeFormulario.new(estrutura)
  rescue DefinicaoDeFormulario::DefinicaoInvalida => e
    flunk "semente #{@semente}, #{contexto}: uma definição válida foi recusada: #{e.message}"
  end

  # --- Definições ----------------------------------------------------------

  def definicao_aleatoria
    @contador = 0
    secoes = (1..@sorteio.rand(1..4)).map do |indice|
      raizes = (1..@sorteio.rand(1..6)).flat_map { subarvore(0) if @contador < 120 }.compact
      raizes = subarvore(0) if raizes.empty?
      { "id" => "s#{indice}", "titulo" => "Seção #{indice}", "perguntas" => raizes }
    end
    estrutura = { "titulo" => "Aleatório", "finalidade" => "testar", "base_legal" => "teste", "secoes" => secoes }
    perguntas = secoes.flat_map { |secao| secao["perguntas"] }
    colunas = perguntas.reject { |pergunta| pergunta["tipo"] == "texto_longo" }.sample(@sorteio.rand(0..3), random: @sorteio)
    estrutura["lista"] = colunas.map { |pergunta| pergunta["chave"] }
    if @sorteio.rand < 0.4
      estrutura["numeracao"] = "manual"
      perguntas.each_with_index { |pergunta, indice| pergunta["numero"] = "#{indice + 1}#{"a" if @sorteio.rand < 0.1}" }
    end
    estrutura
  end

  # A pergunta e, logo depois, as que dependem dela (pré-ordem)
  def subarvore(profundidade, pai = nil)
    pergunta = pergunta_aleatoria(pai)
    escolha = DefinicaoDeFormulario::TIPOS_DE_ESCOLHA.include?(pergunta["tipo"])
    filhas = escolha && profundidade < DefinicaoDeFormulario::MAXIMO_DE_NIVEIS ? @sorteio.rand(0..3) : 0
    [ pergunta ] + (1..filhas).flat_map { @contador < 120 ? subarvore(profundidade + 1, pergunta) : [] }
  end

  def pergunta_aleatoria(pai)
    @contador += 1
    tipo = TIPOS.sample(random: @sorteio)
    pergunta = { "chave" => "p#{@contador}", "texto" => "Pergunta #{@contador}", "tipo" => tipo }
    case tipo
    when "texto" then pergunta["maximo"] = @sorteio.rand(1..200)
    when "texto_longo" then pergunta["maximo"] = @sorteio.rand(1..5000)
    when "numero"
      minimo = @sorteio.rand(-100..100)
      pergunta.merge!("minimo" => minimo, "maximo" => minimo + @sorteio.rand(0..1000), "decimais" => @sorteio.rand(0..3))
    when "data" then pergunta["permite_futuro"] = @sorteio.rand < 0.3
    else
      pergunta["opcoes"] = (1..@sorteio.rand(1..6)).map { |indice| { "codigo" => indice.to_s, "rotulo" => "Opção #{indice}" } }
      pergunta["opcoes"].first["exclusiva"] = true if tipo == "multipla" && pergunta["opcoes"].size > 1 && @sorteio.rand < 0.3
    end
    pergunta["obrigatoria"] = "abertura" if @sorteio.rand < 0.25
    pergunta["ajuda"] = "Ajuda\ncom duas linhas" if @sorteio.rand < 0.2
    if pai
      codigos = pai["opcoes"].map { |opcao| opcao["codigo"] }
      pergunta["condicao"] = { "pergunta" => pai["chave"], "valores" => codigos.sample(@sorteio.rand(1..codigos.size), random: @sorteio) }
    end
    pergunta
  end

  # Uma mudança que (quase sempre) deixa a definição inválida
  def estragar(estrutura)
    perguntas = estrutura["secoes"].flat_map { |secao| secao["perguntas"] }
    alvo = perguntas.sample(random: @sorteio)
    case @sorteio.rand(12)
    when 0 then alvo["tipo"] = LIXO.sample(random: @sorteio)
    when 1 then alvo[%w[chave texto tipo].sample(random: @sorteio)] = LIXO.sample(random: @sorteio)
    when 2 then alvo["campo_estranho"] = 1
    when 3 then alvo["condicao"] = { "pergunta" => perguntas.sample(random: @sorteio)["chave"], "valores" => [ LIXO.sample(random: @sorteio) ] }
    when 4 then alvo["opcoes"] = LIXO.sample(random: @sorteio)
    when 5 then alvo["maximo"] = LIXO.sample(random: @sorteio)
    when 6 then estrutura["secoes"] = LIXO.sample(random: @sorteio)
    when 7 then estrutura["secoes"].sample(random: @sorteio)["perguntas"] = LIXO.sample(random: @sorteio)
    when 8 then estrutura["lista"] = [ LIXO.sample(random: @sorteio) ]
    when 9 then estrutura["encerramento"] = LIXO.sample(random: @sorteio)
    when 10 then estrutura.delete(%w[titulo finalidade base_legal].sample(random: @sorteio))
    else perguntas.reverse!.each_slice(2) { |par| par.first["chave"] = par.last["chave"] if par.size == 2 }
    end
    estrutura
  end

  # --- Respostas -----------------------------------------------------------

  # Em pré-ordem: cada pergunta à mostra recebe uma resposta válida (as
  # obrigatórias sempre; as outras, às vezes)
  def respostas_validas(definicao)
    definicao.perguntas.each_with_object({}) do |pergunta, respostas|
      next unless definicao.visivel?(pergunta, definicao.normalizar(respostas))
      next unless pergunta.obrigatoria == "abertura" || @sorteio.rand < 0.7

      respostas[pergunta.chave] = valor_valido(pergunta)
    end
  end

  def valor_valido(pergunta)
    case pergunta.tipo
    when "texto", "texto_longo" then ("Resposta " * 3)[0, @sorteio.rand(1..pergunta.maximo)].strip.presence || "R"
    when "numero"
      inteiro = @sorteio.rand(pergunta.minimo..pergunta.maximo)
      # A parte decimal afasta do zero: nos extremos, fica o inteiro
      return inteiro.to_s if pergunta.decimais.zero? || inteiro == pergunta.maximo || (inteiro.negative? && inteiro == pergunta.minimo)

      "#{inteiro},#{@sorteio.rand(10**pergunta.decimais).to_s.rjust(pergunta.decimais, "0")}"
    when "data"
      inicio = Date.current - 3650
      fim = pergunta.permite_futuro ? Date.current + 3650 : Date.current
      (inicio + @sorteio.rand((fim - inicio).to_i + 1)).iso8601
    when "unica", "lista_suspensa" then pergunta.codigos.sample(random: @sorteio)
    when "multipla"
      exclusiva = pergunta.opcoes.find(&:exclusiva)
      return [ exclusiva.codigo ] if exclusiva && @sorteio.rand < 0.3

      pergunta.opcoes.reject(&:exclusiva).map(&:codigo).sample(@sorteio.rand(1..[ pergunta.opcoes.size - (exclusiva ? 1 : 0), 1 ].max), random: @sorteio)
    end
  end
end
