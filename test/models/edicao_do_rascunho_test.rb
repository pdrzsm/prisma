require "test_helper"

# As mudanças do gerador num rascunho, uma a uma, e uma sequência aleatória
# delas: o rascunho gravado continua sempre válido, e a mudança recusada não
# grava nada.
class EdicaoDoRascunhoTest < ActiveSupport::TestCase
  setup do
    @formulario = Formulario.create!(chave: "teste", instituicao: instituicoes(:centro))
    @rascunho = @formulario.versoes.create!(numero: 1, estrutura: { "titulo" => "Teste", "secoes" => [] })
  end

  test "seções: criar, renomear, mover e remover (só vazia)" do
    assert editar.adicionar_secao(titulo: "Primeira", descricao: "")
    assert editar.adicionar_secao(titulo: "Segunda", descricao: "Com descrição")
    assert_equal %w[s1 s2], definicao.secoes.map(&:id)

    assert editar.atualizar_secao("s1", titulo: "  Renomeada ", descricao: nil)
    assert_equal "Renomeada", definicao.secoes.first.titulo
    assert editar.mover_secao("s2", "acima")
    assert_equal %w[s2 s1], definicao.secoes.map(&:id)
    assert_not editar.mover_secao("s2", "acima")
    assert_includes @rascunho.errors.full_messages, "Não há para onde mover a seção."
    assert_not editar.mover_secao("s1", "para_o_lado")

    adicionar("s1", texto: "Pergunta")
    assert_not editar.remover_secao("s1")
    assert editar.remover_secao("s2")
    assert_equal %w[s1], definicao.secoes.map(&:id)
    assert editar.adicionar_secao(titulo: "Nova", descricao: "")
    assert_equal %w[s1 s2], definicao.secoes.map(&:id), "o identificador continua a partir do maior"
    assert_raises(ActiveRecord::RecordNotFound) { editar.atualizar_secao("s9", titulo: "X", descricao: nil) }
  end

  test "a chave vem do enunciado e nunca repete uma usada em qualquer versão" do
    editar.adicionar_secao(titulo: "Seção", descricao: "")
    assert_equal "peso_ao_nascer", adicionar("s1", texto: "Peso ao nascer?")
    assert_equal "peso_ao_nascer_2", adicionar("s1", texto: "Peso ao nascer")
    assert_equal "pergunta", adicionar("s1", texto: "123")
    assert_equal "iniciais_2", adicionar("s1", texto: "Iniciais")

    # Publicada a versão 1 e removida a pergunta no rascunho da 2, a chave não volta
    editar.atualizar_cabecalho(titulo: "Teste", descricao: nil, finalidade: "testar", base_legal: "teste", numeracao: "automatica",
                               encerramento: nil, lista: [])
    @rascunho.reload.publicar!(por: users(:admin))
    @rascunho = @formulario.versoes.create!(numero: 2, estrutura: @rascunho.estrutura)
    assert editar.remover_pergunta("peso_ao_nascer")
    assert_equal "peso_ao_nascer_3", adicionar("s1", texto: "Peso ao nascer")
  end

  test "pergunta dependente entra no fim das que já dependem da mesma pergunta" do
    editar.adicionar_secao(titulo: "Seção", descricao: "")
    adicionar("s1", tipo: "unica", texto: "Pai", opcoes: opcoes(2))
    adicionar("s1", texto: "Depois")
    adicionar(nil, controladora: "pai", valores: [ "1" ], texto: "Filha um")
    adicionar(nil, controladora: "filha_um", valores: nil, texto: "Neta", tipo: "texto").then { |chave| assert_nil chave }
    adicionar(nil, controladora: "pai", valores: [ "2" ], texto: "Filha dois", tipo: "unica", opcoes: opcoes(2))
    adicionar(nil, controladora: "filha_dois", valores: [ "1", "2" ], texto: "Neta")

    assert_equal %w[pai filha_um filha_dois neta depois], definicao.chaves
    assert_equal({ "pergunta" => "filha_dois", "valores" => %w[1 2] }, estrutura_da("neta")["condicao"])
  end

  test "alterar mantém a chave e a condição; a definição inteira é conferida" do
    editar.adicionar_secao(titulo: "Seção", descricao: "")
    adicionar("s1", tipo: "unica", texto: "Cor", opcoes: opcoes(2))
    adicionar(nil, controladora: "cor", valores: [ "1" ], texto: "Tom")

    assert editar.atualizar_pergunta("tom", { "texto" => "Tom escolhido", "tipo" => "texto_longo", "maximo" => 300 }, valores: [ "2" ])
    assert_equal({ "pergunta" => "cor", "valores" => [ "2" ] }, estrutura_da("tom")["condicao"])
    assert_equal "Tom escolhido", definicao.pergunta("tom").texto

    # Sem opções que a dependente usa, ou deixando de ser de escolha: recusado, nada muda
    antes = @rascunho.reload.estrutura
    assert_not editar.atualizar_pergunta("cor", { "texto" => "Cor", "tipo" => "unica", "opcoes" => [ { "codigo" => "1", "rotulo" => "Azul" } ] })
    assert_not editar.atualizar_pergunta("cor", { "texto" => "Cor", "tipo" => "texto" })
    assert_equal antes, @rascunho.reload.estrutura
  end

  test "remover tira as dependentes junto e recusa o que é usado fora do grupo" do
    editar.adicionar_secao(titulo: "Seção", descricao: "")
    adicionar("s1", tipo: "unica", texto: "Pai", opcoes: opcoes(2))
    adicionar(nil, controladora: "pai", valores: [ "1" ], texto: "Filha", tipo: "numero")
    adicionar("s1", tipo: "numero", texto: "Outra", nao_maior_que: "filha")
    adicionar("s1", tipo: "data", texto: "Fim")
    editar.atualizar_cabecalho(titulo: "Teste", descricao: nil, finalidade: nil, base_legal: nil, numeracao: "automatica",
                               encerramento: "fim", lista: %w[outra])

    assert_not editar.remover_pergunta("pai")
    assert_includes @rascunho.errors.full_messages.first, "comparação de “Outra”"
    assert_not editar.remover_pergunta("fim")
    assert_includes @rascunho.errors.full_messages.first, "pergunta de encerramento"
    assert_not editar.remover_pergunta("outra")
    assert_includes @rascunho.errors.full_messages.first, "colunas da lista"

    editar.atualizar_cabecalho(titulo: "Teste", descricao: nil, finalidade: nil, base_legal: nil, numeracao: "automatica", encerramento: nil, lista: [])
    assert editar.remover_pergunta("outra")
    assert editar.remover_pergunta("pai")
    assert_equal %w[fim], definicao.chaves
  end

  test "mover troca com a vizinha do mesmo nível, levando as dependentes; a sem condição muda de seção" do
    editar.adicionar_secao(titulo: "A", descricao: "")
    editar.adicionar_secao(titulo: "B", descricao: "")
    adicionar("s1", texto: "Um")
    adicionar("s1", tipo: "unica", texto: "Dois", opcoes: opcoes(2))
    adicionar(nil, controladora: "dois", valores: [ "1" ], texto: "Dois a")
    adicionar(nil, controladora: "dois", valores: [ "2" ], texto: "Dois b")
    adicionar("s2", texto: "Tres")

    assert editar.mover_pergunta("dois", "acima")
    assert_equal %w[dois dois_a dois_b um], chaves_da("s1")
    assert editar.mover_pergunta("dois_b", "acima")
    assert_equal %w[dois dois_b dois_a um], chaves_da("s1")
    assert_not editar.mover_pergunta("dois_b", "acima"), "a primeira dependente não sai de perto da pergunta dela"
    assert editar.mover_pergunta("um", "abaixo")
    assert_equal [ %w[dois dois_b dois_a], %w[um tres] ], definicao.secoes.map { |secao| secao.perguntas.map(&:chave) }
    assert editar.mover_pergunta("dois", "abaixo")
    assert_equal [ [], %w[dois dois_b dois_a um tres] ], definicao.secoes.map { |secao| secao.perguntas.map(&:chave) }
    assert_not editar.mover_pergunta("tres", "abaixo")
  end

  test "numeração manual dá a cada pergunta o número que ela mostrava; a automática tira" do
    editar.adicionar_secao(titulo: "Seção", descricao: "")
    adicionar("s1", texto: "Um")
    adicionar("s1", texto: "Dois")

    editar.atualizar_cabecalho(titulo: "Teste", descricao: nil, finalidade: nil, base_legal: nil, numeracao: "manual", encerramento: nil, lista: nil)
    assert_equal %w[1 2], definicao.perguntas.map(&:numero)
    assert_equal %w[1 2], @rascunho.reload.estrutura["secoes"].first["perguntas"].map { |pergunta| pergunta["numero"] }
    editar.atualizar_cabecalho(titulo: "Teste", descricao: nil, finalidade: nil, base_legal: nil, numeracao: "automatica", encerramento: nil, lista: nil)
    assert @rascunho.reload.estrutura["secoes"].first["perguntas"].none? { |pergunta| pergunta.key?("numero") }
    assert_not editar.atualizar_cabecalho(titulo: "Teste", descricao: nil, finalidade: nil, base_legal: nil, numeracao: "romana", encerramento: nil, lista: nil)
  end

  test "sem o lock_version da tela, ou com um antigo, não grava" do
    assert_raises(ActiveRecord::StaleObjectError) { EdicaoDoRascunho.new(@rascunho, lock_version: nil) }
    assert_raises(ActiveRecord::StaleObjectError) { EdicaoDoRascunho.new(@rascunho, lock_version: "1; DROP TABLE") }
    antigo = @rascunho.lock_version
    editar.adicionar_secao(titulo: "Primeira", descricao: "")

    assert_raises(ActiveRecord::StaleObjectError) do
      EdicaoDoRascunho.new(VersaoFormulario.find(@rascunho.id), lock_version: antigo).adicionar_secao(titulo: "Outra aba", descricao: "")
    end
    assert_equal %w[Primeira], definicao.secoes.map(&:titulo)
  end

  test "versão publicada não é editada" do
    assert_raises(ArgumentError) { EdicaoDoRascunho.new(versoes_formulario(:acompanhamento_v1), lock_version: 0) }
  end

  test "uma sequência aleatória de mudanças, boas e ruins, nunca deixa o rascunho inválido" do
    semente = Integer(ENV.fetch("SEMENTE_DO_GERADOR", Random.new_seed % 100_000))
    sorteio = Random.new(semente)
    recusadas = 0

    250.times do |passo|
      antes = @rascunho.reload.estrutura
      resultado = begin
        mudanca_aleatoria(sorteio)
      rescue ActiveRecord::RecordNotFound
        false
      end
      depois = @rascunho.reload.estrutura

      contexto = "semente #{semente}, passo #{passo}"
      begin
        DefinicaoDeFormulario.new(depois, rascunho: true)
      rescue DefinicaoDeFormulario::DefinicaoInvalida => e
        flunk "rascunho gravado inválido (#{contexto}): #{e.message}"
      end
      assert_equal antes, depois, "mudança recusada não pode gravar (#{contexto})" unless resultado
      recusadas += 1 unless resultado
      chaves = definicao.chaves
      assert_equal chaves.uniq, chaves, contexto
    end
    assert_operator recusadas, :>, 0, "a sequência precisa tentar mudanças inválidas também"
    assert_operator recusadas, :<, 250, "e precisa gravar mudanças também"
  end

  private

  def editar
    EdicaoDoRascunho.new(@rascunho.reload, lock_version: @rascunho.lock_version)
  end

  def definicao
    @rascunho.reload.definicao
  end

  def estrutura_da(chave)
    @rascunho.reload.estrutura["secoes"].flat_map { |secao| secao["perguntas"] }.find { |pergunta| pergunta["chave"] == chave }
  end

  def chaves_da(secao_id)
    definicao.secoes.find { |secao| secao.id == secao_id }.perguntas.map(&:chave)
  end

  def opcoes(quantas)
    (1..quantas).map { |indice| { "codigo" => indice.to_s, "rotulo" => "Opção #{indice}" } }
  end

  def adicionar(secao_id, controladora: nil, valores: nil, tipo: "texto", texto: "Pergunta", **campos)
    editar.adicionar_pergunta(secao_id:, controladora:, valores:, atributos: { "texto" => texto, "tipo" => tipo }.merge(campos.stringify_keys))
  end

  TIPOS = DefinicaoDeFormulario::TIPOS.keys.freeze
  TEXTOS = [ "Peso", "Febre?", "Data da consulta", "", " ", "x" * 600, "Nome‮", "<b>negrito</b>", "Sintomas", "Outro" ].freeze

  # Uma mudança qualquer, com valores bons e ruins; devolve se gravou
  def mudanca_aleatoria(sorteio)
    atual = @rascunho.reload.definicao
    secao = (atual.secoes.map(&:id) + [ "s99" ]).sample(random: sorteio)
    pergunta = (atual.chaves + [ "nao_existe" ]).sample(random: sorteio)
    escolhas = atual.perguntas.select(&:escolha?)
    edicao = editar

    case sorteio.rand(10)
    when 0 then edicao.adicionar_secao(titulo: TEXTOS.sample(random: sorteio), descricao: TEXTOS.sample(random: sorteio))
    when 1 then edicao.atualizar_secao(secao, titulo: TEXTOS.sample(random: sorteio), descricao: nil)
    when 2 then edicao.remover_secao(secao)
    when 3 then edicao.mover_secao(secao, %w[acima abaixo lado].sample(random: sorteio))
    when 4, 5
      controladora = escolhas.sample(random: sorteio) if sorteio.rand < 0.4
      valores = controladora && controladora.codigos.sample(sorteio.rand(0..2), random: sorteio) + ([ "zz" ] if sorteio.rand < 0.1).to_a
      chave = edicao.adicionar_pergunta(secao_id: secao, controladora: controladora&.chave, valores:, atributos: pergunta_aleatoria(sorteio))
      !chave.nil?
    when 6 then edicao.atualizar_pergunta(pergunta, pergunta_aleatoria(sorteio), valores: [ "1" ])
    when 7 then edicao.remover_pergunta(pergunta)
    when 8 then edicao.mover_pergunta(pergunta, %w[acima abaixo].sample(random: sorteio))
    else
      datas = atual.perguntas.select { |candidata| candidata.tipo == "data" }.map(&:chave)
      edicao.atualizar_cabecalho(titulo: TEXTOS.sample(random: sorteio), descricao: nil, finalidade: [ nil, "testar" ].sample(random: sorteio),
                                 base_legal: nil, numeracao: %w[automatica manual automatica].sample(random: sorteio),
                                 encerramento: (datas + [ nil, "nao_existe" ]).sample(random: sorteio),
                                 lista: atual.chaves.sample(sorteio.rand(0..4), random: sorteio))
    end
  end

  def pergunta_aleatoria(sorteio)
    tipo = (TIPOS + [ "arquivo" ]).sample(random: sorteio)
    atributos = { "texto" => TEXTOS.sample(random: sorteio), "tipo" => tipo }
    atributos["obrigatoria"] = [ "abertura", "encerramento" ].sample(random: sorteio) if sorteio.rand < 0.3
    case tipo
    when "texto", "texto_longo" then atributos["maximo"] = [ 0, 10, 200, 5000, 9999 ].sample(random: sorteio)
    when "numero" then atributos.merge!("minimo" => sorteio.rand(-5..5), "maximo" => sorteio.rand(-5..50), "decimais" => sorteio.rand(0..4))
    when "data" then atributos["permite_futuro"] = sorteio.rand < 0.5
    when "unica", "lista_suspensa", "multipla"
      atributos["opcoes"] = (1..sorteio.rand(0..4)).map { |indice| { "codigo" => [ indice.to_s, "a b" ].sample(random: sorteio), "rotulo" => "Opção #{indice}" } }
    end
    atributos
  end
end
