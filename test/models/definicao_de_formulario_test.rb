require "test_helper"

# O motor de formulários: cada regra de uma definição (o que o gerador grava)
# e de uma resposta (o que quem preenche envia), com o caso aceito e o
# recusado. As entradas malformadas nunca levantam erro inesperado: viram uma
# mensagem para a tela.
class DefinicaoDeFormularioTest < ActiveSupport::TestCase
  setup { @formulario = FormulariosDeTeste.acompanhamento }

  # --- O formulário de teste (FormulariosDeTeste::ACOMPANHAMENTO) ----------

  test "o formulário de teste tem a numeração do papel, sem a identificação, e as obrigatórias de cada momento" do
    assert_equal [ "3" ] + (5..25).map(&:to_s), @formulario.perguntas.map(&:numero)
    assert_equal %w[5 6 7 8 9 10], numeros_com(obrigatoria: "abertura")
    assert_equal %w[11 12 14 15 18], numeros_com(obrigatoria: "encerramento")
    assert_not @formulario.chaves.intersect?(%w[prontuario_sah prontuario_aghuse iniciais])
    assert_equal "texto_longo", @formulario.pergunta("motivo_mudanca_tratamento").tipo
    assert @formulario.finalidade.present? && @formulario.base_legal.present?
    assert_not @formulario.rascunho?
  end

  test "respostas de abertura bastam para salvar" do
    assert_empty validar(respostas_de_abertura)
  end

  test "obrigatórias de abertura" do
    erros = validar(respostas_de_abertura.except("gestante", "municipio_residencia"))

    assert_equal [ "é obrigatória" ], erros["gestante"]
    assert_equal [ "é obrigatória" ], erros["municipio_residencia"]
  end

  test "ao preencher o encerramento, as perguntas marcadas para encerrar viram obrigatórias" do
    erros = validar(respostas_de_abertura("data_encerramento" => Date.current.iso8601))

    assert_equal numeros_com(obrigatoria: "encerramento").size, erros.size
    assert_equal [ "é obrigatória para encerrar a notificação" ], erros["exame_imagem"]
    assert_empty validar(respostas_de_abertura.merge(respostas_de_encerramento))
  end

  test "pergunta 10 só vale para a forma disseminada" do
    localizada = @formulario.normalizar(respostas_de_abertura("forma" => "1", "locais" => [ "1" ]))
    assert_not localizada.key?("locais")

    assert_equal [ "é obrigatória" ], validar(respostas_de_abertura("forma" => "2"))["locais"]
    assert_empty validar(respostas_de_abertura("forma" => "3", "locais" => [ "1", "10" ]))
  end

  test "as opções 2 e 3 da pergunta 9 revelam a pergunta 10, a primeira dependente dela" do
    forma = @formulario.pergunta("forma")

    assert_equal [ "locais" ], @formulario.dependentes(forma).map(&:chave)
    assert_equal [ [], [ 1 ], [ 1 ] ], %w[1 2 3].map { |codigo| @formulario.revelados_por(forma, codigo) }
    assert_equal forma, @formulario.controladora(@formulario.pergunta("locais"))
    assert_equal 1, @formulario.pergunta("locais").profundidade
  end

  test "opções exclusivas não combinam com outras" do
    assert_match "“Não” não pode ser marcada", validar(respostas_de_abertura("populacoes_especiais" => %w[0 1]))["populacoes_especiais"].first
    assert_empty validar(respostas_de_abertura("imagem_complementar" => %w[1 3]))
    assert_not_empty validar(respostas_de_abertura("imagem_complementar" => %w[2 1]))["imagem_complementar"]
  end

  test "opção inexistente e campo desconhecido são recusados" do
    erros = validar(respostas_de_abertura("gestante" => "7", "campo_inventado" => "x"))

    assert_equal [ "tem uma opção inválida" ], erros["gestante"]
    assert_match "campo_inventado", erros["base"].first
  end

  test "números inteiros e comparação entre perguntas" do
    assert_equal [ "deve ser um número inteiro" ], validar(respostas_de_abertura("numero_contatos" => "três"))["numero_contatos"]
    assert_match "não pode ser maior que", validar(respostas_de_abertura("numero_contatos" => "2", "numero_contatos_avaliados" => "5"))["numero_contatos_avaliados"].first
    assert_empty validar(respostas_de_abertura("numero_contatos" => "5", "numero_contatos_avaliados" => "5"))
  end

  test "datas válidas, não futuras e revisão depois do encerramento" do
    amanha = Date.current.tomorrow.iso8601
    hoje = Date.current.iso8601
    ontem = Date.current.yesterday.iso8601

    assert_equal [ "não é uma data válida" ], validar(respostas_de_abertura("data_revisao_encerramento" => "2026-02-30"))["data_revisao_encerramento"]
    assert_equal [ "não pode ser no futuro" ], validar(respostas_de_abertura("data_revisao_encerramento" => amanha))["data_revisao_encerramento"]
    erros = validar(respostas_de_abertura.merge(respostas_de_encerramento, "data_encerramento" => hoje, "data_revisao_encerramento" => ontem))
    assert_match "não pode ser antes de", erros["data_revisao_encerramento"].first
  end

  test "normalização limpa espaços, converte números e descarta vazios" do
    respostas = @formulario.normalizar(respostas_de_abertura("municipio_residencia" => "  Cidade   Fictícia ", "numero_contatos" => "4",
                                                     "contagem_final" => "", "comorbidades" => [ "" ]))

    assert_equal "Cidade Fictícia", respostas["municipio_residencia"]
    assert_equal 4, respostas["numero_contatos"]
    assert_equal [ "0" ], respostas["populacoes_especiais"]
    assert_not respostas.key?("contagem_final")
    assert_not respostas.key?("comorbidades")
  end

  test "resposta formatada usa os rótulos e a data brasileira" do
    assert_equal "Localizada + disseminada", @formulario.resposta_formatada(@formulario.pergunta("forma"), "3")
    assert_equal "Pele; Articulações", @formulario.resposta_formatada(@formulario.pergunta("locais"), %w[1 2])
    assert_equal "07/01/2019", @formulario.resposta_formatada(@formulario.pergunta("data_encerramento"), "2019-01-07")
  end

  test "parâmetros permitidos são só as perguntas do formulário" do
    permitidos = @formulario.parametros_permitidos

    assert_includes permitidos, "forma"
    assert_includes permitidos, { "locais" => [] }
    assert_not_includes permitidos, "iniciais"
    assert_equal @formulario.perguntas.size, permitidos.size
  end

  # --- Definição: o que é aceito -------------------------------------------

  test "uma definição mínima é aceita, e o rascunho aceita o que ainda falta para publicar" do
    assert_nothing_raised { DefinicaoDeFormulario.new(estrutura_de_formulario) }

    rascunho = DefinicaoDeFormulario.new({ "titulo" => "Só o título" }, rascunho: true)
    assert rascunho.rascunho?
    assert_empty rascunho.secoes
    assert_nil rascunho.finalidade
  end

  test "publicar exige finalidade, base legal, perguntas e nenhuma seção vazia" do
    %w[finalidade base_legal].each do |campo|
      [ nil, "  ", [ "lista" ] ].each do |valor|
        assert_recusada estrutura_de_formulario(campo => valor), campo == "finalidade" ? "Finalidade" : "Base legal"
      end
    end
    assert_recusada estrutura_de_formulario([]), "não tem perguntas"
    assert_recusada estrutura_de_formulario(secoes: []), "pelo menos uma pergunta"
    vazia = estrutura_de_formulario.tap { |estrutura| estrutura["secoes"] << { "id" => "s2", "titulo" => "Vazia", "perguntas" => [] } }
    assert_recusada vazia, "Seção “Vazia”: não tem perguntas"
    assert_nothing_raised { DefinicaoDeFormulario.new(vazia, rascunho: true) }
  end

  test "título é obrigatório até no rascunho" do
    assert_recusada({ "titulo" => " " }, "Título do formulário: falta preencher", rascunho: true)
    assert_recusada({ "titulo" => 42 }, "Título do formulário: precisa ser um texto", rascunho: true)
  end

  test "a estrutura canônica tem só campos conhecidos, os padrões explícitos e volta igual pelo JSON" do
    definicao = DefinicaoDeFormulario.new(estrutura_de_formulario([
      { "chave" => "peso", "texto" => "Peso", "tipo" => "numero", "decimais" => 1 },
      { "chave" => "nome_curto", "texto" => "Apelido", "tipo" => "texto" }
    ]))
    peso, apelido = definicao.estrutura["secoes"].first["perguntas"]

    assert_equal({ "chave" => "peso", "texto" => "Peso", "tipo" => "numero", "minimo" => 0, "maximo" => 100_000, "decimais" => 1 }, peso)
    assert_equal 100, apelido["maximo"]
    assert_equal "automatica", definicao.estrutura["numeracao"]
    assert_equal definicao.estrutura, DefinicaoDeFormulario.new(JSON.parse(definicao.estrutura.to_json)).estrutura
    assert_equal @formulario.estrutura, DefinicaoDeFormulario.new(JSON.parse(@formulario.estrutura.to_json)).estrutura
  end

  test "a definição e tudo dentro dela ficam congelados" do
    assert @formulario.frozen?
    assert @formulario.estrutura.frozen?
    assert @formulario.estrutura["secoes"].first["perguntas"].first["texto"].frozen?
    assert @formulario.perguntas.frozen?
    assert @formulario.pergunta("gestante").opcoes.frozen?
    assert_raises(FrozenError) { @formulario.perguntas << nil }
  end

  test "textos são limpos: espaços padronizados e caracteres invisíveis ou de direção removidos" do
    definicao = DefinicaoDeFormulario.new(estrutura_de_formulario(
      [ { "chave" => "campo", "texto" => "  Campo‮ ​  invertido\u0000 ", "tipo" => "texto",
          "ajuda" => "Primeira linha  \r\n\r\n\r\n\r\nSegunda\t linha" } ],
      titulo: "Título⁦ com\n quebra", descricao: "Uma linha\nOutra linha\n"
    ))

    assert_equal "Campo invertido", definicao.pergunta("campo").texto
    assert_equal "Primeira linha\n\nSegunda  linha", definicao.pergunta("campo").ajuda
    assert_equal "Título com quebra", definicao.titulo
    assert_equal "Uma linha\nOutra linha", definicao.descricao
  end

  # --- Definição: o que é recusado -----------------------------------------

  test "campos desconhecidos são recusados em todos os níveis" do
    assert_recusada estrutura_de_formulario(script: "x"), "Formulário: campos desconhecidos (script)"
    secao = estrutura_de_formulario.tap { |estrutura| estrutura["secoes"].first["estilo"] = "x" }
    assert_recusada secao, "campos desconhecidos (estilo)"
    assert_recusada estrutura_de_formulario([ texto("campo", "html" => "<b>") ]), "campos desconhecidos (html)"
    assert_recusada estrutura_de_formulario([ unica("campo", opcoes: [ { "codigo" => "1", "rotulo" => "Sim", "cor" => "red" } ]) ]), "campos desconhecidos (cor)"
    assert_recusada estrutura_de_formulario([ unica("pai"), texto("filho", "condicao" => { "pergunta" => "pai", "valores" => [ "1" ], "e" => "x" }) ]),
                    "campos desconhecidos (e)"
  end

  test "campos de outro tipo de pergunta também são desconhecidos" do
    assert_recusada estrutura_de_formulario([ texto("campo", "opcoes" => []) ]), "campos desconhecidos (opcoes)"
    assert_recusada estrutura_de_formulario([ texto("campo", "decimais" => 1) ]), "campos desconhecidos (decimais)"
    assert_recusada estrutura_de_formulario([ unica("campo", "maximo" => 3) ]), "campos desconhecidos (maximo)"
    assert_recusada estrutura_de_formulario([ texto("campo", "tipo" => "data", "maximo" => 3) ]), "campos desconhecidos (maximo)"
  end

  test "valores do tipo errado são recusados, sem levantar outro erro" do
    [
      [ { "titulo" => [ "x" ] }, "precisa ser um texto" ],
      [ estrutura_de_formulario(secoes: { "s1" => {} }), "Seções: precisa ser uma lista" ],
      [ estrutura_de_formulario(secoes: [ "texto" ]), "Seção 1: precisa ser um conjunto de campos" ],
      [ estrutura_de_formulario([ "texto" ]), "pergunta 1: precisa ser um conjunto de campos" ],
      [ estrutura_de_formulario([ texto("campo", "maximo" => "30") ]), "limite de caracteres: precisa ser um número inteiro" ],
      [ estrutura_de_formulario([ texto("campo", "maximo" => 30.5) ]), "precisa ser um número inteiro" ],
      [ estrutura_de_formulario([ texto("campo", "obrigatoria" => true) ]), "obrigatoriedade: valor desconhecido" ],
      [ estrutura_de_formulario([ unica("campo", opcoes: { "1" => "Sim" }) ]), "opções: precisa ser uma lista" ],
      [ estrutura_de_formulario([ unica("campo", opcoes: [ "Sim" ]) ]), "opção 1: precisa ser um conjunto de campos" ],
      [ estrutura_de_formulario([ multipla("campo", opcoes: [ { "codigo" => "1", "rotulo" => "Sim", "exclusiva" => "sim" } ]) ]), "exclusiva: precisa ser sim ou não" ],
      [ estrutura_de_formulario([ data("campo", "permite_futuro" => "true") ]), "data futura: precisa ser sim ou não" ],
      [ estrutura_de_formulario([ unica("pai"), texto("filho", "condicao" => [ "pai" ]) ]), "a condição precisa ser um conjunto de campos" ],
      [ estrutura_de_formulario(lista: "campo"), "colunas da lista" ],
      [ estrutura_de_formulario(numeracao: "romana"), "Numeração das perguntas: valor desconhecido" ],
      [ "não é um Hash", "precisa ser um conjunto de campos" ],
      [ nil, "precisa ser um conjunto de campos" ]
    ].each do |estrutura, trecho|
      assert_recusada estrutura, trecho
    end
  end

  test "chave de pergunta inválida, reservada ou repetida é recusada" do
    %w[Maiuscula 1comeca com-hifen com\ espaco].each do |chave|
      assert_recusada estrutura_de_formulario([ texto(chave) ]), "chave inválida"
    end
    assert_recusada estrutura_de_formulario([ texto("a" * 65) ]), "chave inválida"
    assert_nothing_raised { DefinicaoDeFormulario.new(estrutura_de_formulario([ texto("a" * 64) ])) }
    %w[iniciais prontuario_sah setor_id lock_version base].each do |chave|
      assert_recusada estrutura_de_formulario([ texto(chave) ]), "é reservada pelo sistema"
    end
    assert_recusada estrutura_de_formulario([ texto("campo"), texto("campo") ]), "Há perguntas com a mesma chave"
  end

  test "tipo de pergunta desconhecido é recusado" do
    %w[arquivo html script].each do |tipo|
      assert_recusada estrutura_de_formulario([ texto("campo", "tipo" => tipo) ]), "tipo de pergunta desconhecido"
    end
  end

  test "opções: códigos válidos e únicos, rótulos únicos, exclusiva só na múltipla" do
    assert_recusada estrutura_de_formulario([ unica("campo", opcoes: []) ]), "precisa de pelo menos uma opção"
    [ "", " 1", "um dois", "a" * 17, "<b>", "1;2" ].each do |codigo|
      assert_recusada estrutura_de_formulario([ unica("campo", opcoes: [ { "codigo" => codigo, "rotulo" => "X" } ]) ]), "código inválido"
    end
    assert_recusada estrutura_de_formulario([ unica("campo", %w[1 1]) ]), "códigos de opção repetidos"
    opcoes = [ { "codigo" => "1", "rotulo" => "Sim" }, { "codigo" => "2", "rotulo" => "SIM" } ]
    assert_recusada estrutura_de_formulario([ unica("campo", opcoes:) ]), "opções com o mesmo rótulo"
    exclusiva = [ { "codigo" => "0", "rotulo" => "Não", "exclusiva" => true } ]
    assert_recusada estrutura_de_formulario([ unica("campo", opcoes: exclusiva) ]), "só a múltipla escolha tem opção exclusiva"
    assert_nothing_raised { DefinicaoDeFormulario.new(estrutura_de_formulario([ multipla("campo", opcoes: exclusiva) ])) }
  end

  test "limites de quantidade" do
    secoes = (1..31).map { |indice| { "id" => "s#{indice}", "titulo" => "Seção #{indice}", "perguntas" => [ texto("p#{indice}") ] } }
    assert_recusada estrutura_de_formulario(secoes:), "Seções: no máximo 30"
    assert_recusada estrutura_de_formulario((1..301).map { |indice| texto("p#{indice}") }), "no máximo 300"
    distribuidas = (1..11).map { |indice| { "id" => "s#{indice}", "titulo" => "Seção #{indice}", "perguntas" => (1..28).map { |posicao| texto("p#{indice}_#{posicao}") } } }
    assert_recusada estrutura_de_formulario(secoes: distribuidas), "passa de 300 perguntas"
    assert_recusada estrutura_de_formulario([ unica("campo", (1..101).map(&:to_s)) ]), "opções: no máximo 100"
    muitas_opcoes = (1..31).map { |indice| unica("p#{indice}", (1..100).map(&:to_s)) }
    assert_recusada estrutura_de_formulario(muitas_opcoes), "passa de 3000 opções no total"
  end

  test "limites de tamanho dos textos e dos números" do
    assert_recusada estrutura_de_formulario(titulo: "x" * 151), "Título do formulário: no máximo 150 caracteres"
    assert_recusada estrutura_de_formulario(finalidade: "x" * 1001), "Finalidade: no máximo 1000 caracteres"
    assert_recusada estrutura_de_formulario([ texto("campo", "texto" => "x" * 501) ]), "enunciado: no máximo 500 caracteres"
    assert_recusada estrutura_de_formulario([ texto("campo", "ajuda" => "x" * 501) ]), "texto de ajuda: no máximo 500 caracteres"
    assert_recusada estrutura_de_formulario([ unica("campo", opcoes: [ { "codigo" => "1", "rotulo" => "x" * 201 } ]) ]), "rótulo: no máximo 200 caracteres"
    assert_recusada estrutura_de_formulario([ texto("campo", "maximo" => 201) ]), "de 1 a 200"
    assert_recusada estrutura_de_formulario([ texto("campo", "maximo" => 0) ]), "de 1 a 200"
    assert_recusada estrutura_de_formulario([ texto("campo", "tipo" => "texto_longo", "maximo" => 5001) ]), "de 1 a 5000"
    assert_recusada estrutura_de_formulario([ numero("campo", "decimais" => 4) ]), "casas decimais: precisa ser um número inteiro de 0 a 3"
    assert_recusada estrutura_de_formulario([ numero("campo", "maximo" => 1_000_000_001) ]), "valor máximo"
    assert_recusada estrutura_de_formulario([ numero("campo", "minimo" => 10, "maximo" => 5) ]), "o valor mínimo não pode ser maior que o máximo"
  end

  test "definição grande demais ou que não vira JSON é recusada antes de ser lida" do
    assert_recusada estrutura_de_formulario(titulo: "x" * 1_000_001), "não pôde ser lida"
    assert_recusada estrutura_de_formulario(titulo: "\xFF".dup.force_encoding("BINARY")), "não pôde ser lida"
    assert_recusada estrutura_de_formulario(titulo: Float::NAN), "não pôde ser lida"
  end

  test "a condição depende de uma pergunta de escolha logo acima, na mesma seção" do
    assert_nothing_raised { DefinicaoDeFormulario.new(estrutura_de_formulario([ unica("pai"), texto("filho", **condicao("pai", "1")) ])) }

    mensagem = "a condição precisa depender de uma pergunta de escolha logo acima dela"
    # Outra pergunta, que não depende do pai, no meio
    assert_recusada estrutura_de_formulario([ unica("pai"), texto("outra"), texto("filho", **condicao("pai", "1")) ]), mensagem
    # Depois do filho, não antes
    assert_recusada estrutura_de_formulario([ texto("filho", **condicao("pai", "1")), unica("pai") ]), mensagem
    # Ela mesma
    assert_recusada estrutura_de_formulario([ unica("filho", **condicao("filho", "1")) ]), mensagem
    # Em outra seção
    secoes = [ { "id" => "s1", "titulo" => "A", "perguntas" => [ unica("pai") ] },
               { "id" => "s2", "titulo" => "B", "perguntas" => [ texto("filho", **condicao("pai", "1")) ] } ]
    assert_recusada estrutura_de_formulario(secoes:), mensagem
    # Que não existe
    assert_recusada estrutura_de_formulario([ texto("filho", **condicao("fantasma", "1")) ]), mensagem
  end

  test "irmãs e netas podem ficar entre a controladora e uma dependente" do
    perguntas = [
      unica("pai"),
      unica("filha", **condicao("pai", "1")),
      texto("neta", **condicao("filha", "2")),
      texto("segunda_filha", **condicao("pai", "2"))
    ]
    definicao = DefinicaoDeFormulario.new(estrutura_de_formulario(perguntas))

    assert_equal %w[filha segunda_filha], definicao.dependentes(definicao.pergunta("pai")).map(&:chave)
    assert_equal [ 0, 1, 2, 1 ], definicao.perguntas.map(&:profundidade)
    assert_equal %w[pai], definicao.raizes(definicao.secoes.first).map(&:chave)
    assert_equal [ 2 ], definicao.revelados_por(definicao.pergunta("pai"), "2")
  end

  test "a controladora é de escolha, e a condição usa opções que ela tem" do
    assert_recusada estrutura_de_formulario([ texto("pai"), texto("filho", **condicao("pai", "1")) ]), "só uma pergunta de escolha"
    assert_recusada estrutura_de_formulario([ unica("pai"), texto("filho", **condicao("pai", "9")) ]), "usa opções que “Pai” não tem"
    assert_recusada estrutura_de_formulario([ unica("pai"), texto("filho", **condicao("pai")) ]), "escolha pelo menos uma opção"
    assert_recusada estrutura_de_formulario([ unica("pai"), texto("filho", **condicao("pai", "1", "1")) ]), "opções inválidas ou repetidas"
    %w[lista_suspensa multipla].each do |tipo|
      assert_nothing_raised { DefinicaoDeFormulario.new(estrutura_de_formulario([ unica("pai", "tipo" => tipo), texto("filho", **condicao("pai", "1")) ])) }
    end
  end

  test "no máximo 3 níveis de condição e 10 dependentes diretas" do
    niveis = [ unica("n0") ] + (1..3).map { |nivel| unica("n#{nivel}", **condicao("n#{nivel - 1}", "1")) }
    assert_nothing_raised { DefinicaoDeFormulario.new(estrutura_de_formulario(niveis)) }
    assert_recusada estrutura_de_formulario(niveis + [ texto("n4", **condicao("n3", "1")) ]), "passa de 3 níveis de condição"

    dez = [ unica("pai") ] + (1..10).map { |indice| texto("d#{indice}", **condicao("pai", "1")) }
    assert_nothing_raised { DefinicaoDeFormulario.new(estrutura_de_formulario(dez)) }
    assert_recusada estrutura_de_formulario(dez + [ texto("d11", **condicao("pai", "1")) ]), "no máximo 10 perguntas podem depender dela"
  end

  test "comparações apontam para outra pergunta do tipo certo" do
    assert_nothing_raised { DefinicaoDeFormulario.new(estrutura_de_formulario([ numero("total"), numero("parte", "nao_maior_que" => "total") ])) }
    assert_recusada estrutura_de_formulario([ texto("total"), numero("parte", "nao_maior_que" => "total") ]), "outra pergunta de número"
    assert_recusada estrutura_de_formulario([ numero("parte", "nao_maior_que" => "parte") ]), "outra pergunta de número"
    assert_recusada estrutura_de_formulario([ numero("parte", "nao_maior_que" => "fantasma") ]), "outra pergunta de número"
    assert_recusada estrutura_de_formulario([ numero("inicio"), data("fim", "nao_antes_de" => "inicio") ]), "outra pergunta de data"
    assert_recusada estrutura_de_formulario([ data("fim", "nao_antes_de" => "Maiuscula") ]), "referência inválida"
  end

  test "a pergunta de encerramento é uma data sem condição, sem data futura e não obrigatória" do
    assert_nothing_raised { DefinicaoDeFormulario.new(estrutura_de_formulario([ data("fim") ], encerramento: "fim")) }
    mensagem = "A pergunta de encerramento precisa ser uma data"
    assert_recusada estrutura_de_formulario([ texto("fim") ], encerramento: "fim"), mensagem
    assert_recusada estrutura_de_formulario([ data("fim", "permite_futuro" => true) ], encerramento: "fim"), mensagem
    assert_recusada estrutura_de_formulario([ data("fim", "obrigatoria" => "abertura") ], encerramento: "fim"), mensagem
    assert_recusada estrutura_de_formulario([ unica("pai"), data("fim", **condicao("pai", "1")) ], encerramento: "fim"), mensagem
    assert_recusada estrutura_de_formulario([ data("fim") ], encerramento: "fantasma"), mensagem
    assert_recusada estrutura_de_formulario([ texto("campo", "obrigatoria" => "encerramento") ]), "precisa de uma pergunta de encerramento"
  end

  test "colunas da lista: até 3 perguntas diferentes, sem texto longo" do
    perguntas = %w[a b c d].map { |chave| texto(chave) } + [ texto("longo", "tipo" => "texto_longo") ]
    assert_nothing_raised { DefinicaoDeFormulario.new(estrutura_de_formulario(perguntas, lista: %w[a b c])) }
    [ %w[a b c d], %w[a a], %w[fantasma], %w[longo], [ 1 ] ].each do |lista|
      assert_recusada estrutura_de_formulario(perguntas, lista:), "colunas da lista"
    end
  end

  test "numeração automática conta em pré-ordem; a manual exige um número único em cada pergunta" do
    perguntas = [ unica("pai"), texto("filho", **condicao("pai", "1")), texto("depois") ]
    assert_equal %w[1 2 3], DefinicaoDeFormulario.new(estrutura_de_formulario(perguntas)).perguntas.map(&:numero)

    manual = perguntas.zip(%w[1 1a 2]).map { |pergunta, numero| pergunta.merge("numero" => numero) }
    assert_equal %w[1 1a 2], DefinicaoDeFormulario.new(estrutura_de_formulario(manual, numeracao: "manual")).perguntas.map(&:numero)
    assert_recusada estrutura_de_formulario(perguntas, numeracao: "manual"), "falta o número"
    assert_recusada estrutura_de_formulario(manual.map { |pergunta| pergunta.merge("numero" => "7") }, numeracao: "manual"), "mesmo número"
    assert_recusada estrutura_de_formulario([ texto("campo", "numero" => "7 b") ], numeracao: "manual"), "número inválido"
    assert_recusada estrutura_de_formulario(manual), "com a numeração automática, a pergunta não tem número próprio"
  end

  test "seções com identificador válido e único" do
    [ "1", "s0", "secao", "s12345", nil ].each do |id|
      assert_recusada estrutura_de_formulario.tap { |estrutura| estrutura["secoes"].first["id"] = id }, "identificador inválido"
    end
    duas = [ { "id" => "s1", "titulo" => "A", "perguntas" => [ texto("a") ] }, { "id" => "s1", "titulo" => "B", "perguntas" => [ texto("b") ] } ]
    assert_recusada estrutura_de_formulario(secoes: duas), "seções com o mesmo identificador"
  end

  test "todos os erros vêm de uma vez, cada um dizendo onde está" do
    erro = assert_raises(DefinicaoDeFormulario::DefinicaoInvalida) do
      DefinicaoDeFormulario.new(estrutura_de_formulario([ texto("um", "maximo" => 0), texto("dois", "texto" => "") ], finalidade: ""))
    end

    assert_operator erro.erros.size, :>=, 3
    assert_includes erro.erros.map(&:onde), "um"
    assert_includes erro.erros.map(&:onde), "dois"
    assert_includes erro.erros.map(&:onde), :formulario
  end

  # --- Respostas, por tipo --------------------------------------------------

  test "texto curto: uma linha, limpa, com limite" do
    definicao = definicao_com([ texto("campo", "maximo" => 10) ])

    assert_equal "Ana Maria", definicao.normalizar("campo" => " Ana\n\t Maria​ ")["campo"]
    assert_equal [ "tem mais de 10 caracteres" ], erros_de_resposta(definicao, "campo" => "x" * 11)["campo"]
    assert_nil definicao.normalizar("campo" => " ​ ")["campo"]
  end

  test "texto longo: mantém os parágrafos" do
    definicao = definicao_com([ texto("relato", "tipo" => "texto_longo", "maximo" => 30) ])

    assert_equal "Linha um\n\nLinha dois", definicao.normalizar("relato" => "Linha um  \r\n\r\n\r\nLinha dois‮")["relato"]
    assert_equal [ "tem mais de 30 caracteres" ], erros_de_resposta(definicao, "relato" => "x" * 31)["relato"]
  end

  test "número inteiro: limites e sinal" do
    definicao = definicao_com([ numero("temperatura", "minimo" => -10, "maximo" => 50) ])

    assert_equal(-5, definicao.normalizar("temperatura" => " -5 ")["temperatura"])
    assert_equal 1000, definicao.normalizar("temperatura" => "1 000")["temperatura"]
    assert_equal [ "deve ser no mínimo -10" ], erros_de_resposta(definicao, "temperatura" => "-11")["temperatura"]
    assert_equal [ "deve ser no máximo 50" ], erros_de_resposta(definicao, "temperatura" => "51")["temperatura"]
    [ "1,5", "1.5", "1e3", "0x10", "--1", "doze" ].each do |valor|
      assert_equal [ "deve ser um número inteiro" ], erros_de_resposta(definicao, "temperatura" => valor)["temperatura"], valor
    end
    assert_equal [ "deve ser um número inteiro" ], erros_de_resposta(definicao, "temperatura" => "9" * 16)["temperatura"]
  end

  test "número decimal: vírgula ou ponto, gravado como texto exato e mostrado com vírgula" do
    definicao = definicao_com([ numero("peso", "decimais" => 2, "minimo" => 0, "maximo" => 500) ])
    peso = definicao.pergunta("peso")

    assert_equal "72.5", definicao.normalizar("peso" => "72,50")["peso"]
    assert_equal "72", definicao.normalizar("peso" => "72.0")["peso"]
    assert_equal "0.1", definicao.normalizar("peso" => "0.10")["peso"]
    assert_equal "72,5", definicao.resposta_formatada(peso, "72.5")
    assert_empty erros_de_resposta(definicao, "peso" => "0,07")
    assert_equal [ "deve ter no máximo 2 casas decimais" ], erros_de_resposta(definicao, "peso" => "1,234")["peso"]
    assert_equal [ "deve ser no máximo 500" ], erros_de_resposta(definicao, "peso" => "500.01")["peso"]
    assert_equal [ "deve ser um número" ], erros_de_resposta(definicao, "peso" => "1.2.3")["peso"]
    assert_equal [ "deve ser um número" ], erros_de_resposta(definicao, "peso" => "NaN")["peso"]
  end

  test "data: válida, entre 1900 e 2199 e no futuro só se a pergunta aceitar" do
    definicao = definicao_com([ data("consulta"), data("retorno", "permite_futuro" => true) ])
    futuro = (Date.current + 30).iso8601

    assert_equal [ "não pode ser no futuro" ], erros_de_resposta(definicao, "consulta" => futuro)["consulta"]
    assert_empty erros_de_resposta(definicao, "retorno" => futuro)
    assert_equal [ "deve estar entre 1900 e 2199" ], erros_de_resposta(definicao, "consulta" => "1899-12-31")["consulta"]
    assert_equal [ "deve estar entre 1900 e 2199" ], erros_de_resposta(definicao, "retorno" => "2200-01-01")["retorno"]
    [ "31/12/2020", "2020-13-01", "2020-1-1", "hoje" ].each do |valor|
      assert_equal [ "não é uma data válida" ], erros_de_resposta(definicao, "consulta" => valor)["consulta"], valor
    end
  end

  test "lista suspensa: só os códigos das opções" do
    definicao = definicao_com([ unica("cor", %w[1 2], "tipo" => "lista_suspensa") ])

    assert_empty erros_de_resposta(definicao, "cor" => "2")
    assert_equal [ "tem uma opção inválida" ], erros_de_resposta(definicao, "cor" => "3")["cor"]
    assert_equal [ "tem uma opção inválida" ], erros_de_resposta(definicao, "cor" => [ "1" ])["cor"]
  end

  test "múltipla escolha: sem repetidos e sem vazios" do
    definicao = definicao_com([ multipla("sintomas", %w[1 2 3]) ])

    assert_equal %w[1 2], definicao.normalizar("sintomas" => [ "1", "", "2", "1", " 2 " ])["sintomas"]
    assert_nil definicao.normalizar("sintomas" => [ "", nil ])["sintomas"]
    assert_equal [ "tem uma opção inválida" ], erros_de_resposta(definicao, "sintomas" => %w[1 9])["sintomas"]
  end

  test "resposta com formato errado vira erro de validação, nunca exceção" do
    definicao = definicao_com([
      texto("texto"), texto("longo", "tipo" => "texto_longo"), numero("inteiro"), numero("decimal", "decimais" => 1), data("data"),
      unica("unica"), unica("lista", "tipo" => "lista_suspensa"), multipla("multipla")
    ])
    estranhos = [ { "a" => "1" }, [ [ "1" ] ], [ { "a" => 1 } ], true, false, 1.5, Float::INFINITY, :simbolo, Object.new, "x" * 100_000,
                  "\xFF\xFE".dup.force_encoding("BINARY"), "1\u0000", [ nil ], [ true ] ]

    definicao.chaves.product(estranhos).each do |chave, valor|
      erros = begin
        erros_de_resposta(definicao, chave => valor)
      rescue StandardError => e
        flunk "#{chave} = #{valor.inspect[0, 40]} levantou #{e.class}: #{e.message}"
      end
      assert erros.empty? || erros.key?(chave), "#{chave}: #{erros.inspect}"
    end
    assert_equal({ "base" => [ "As respostas devem ser um conjunto de campos." ] }, definicao.validar([ "lista" ]))
    assert_equal "texto", definicao.normalizar("texto")
  end

  test "chaves desconhecidas são citadas sem despejar o que veio" do
    erros = erros_de_resposta(definicao_com([ texto("campo") ]), (1..20).to_h { |indice| [ "#{"x" * 100}#{indice}", "1" ] })

    assert_operator erros["base"].first.length, :<, 300
  end

  # --- Respostas e condições -------------------------------------------------

  test "condição em cadeia: sem a controladora, as dependentes e as dependentes delas somem" do
    definicao = definicao_com([
      unica("tem_sintomas", %w[0 1]),
      multipla("sintomas", %w[1 2 3], **condicao("tem_sintomas", "1")),
      texto("detalhe_febre", **condicao("sintomas", "1"), "obrigatoria" => "abertura")
    ])
    completas = { "tem_sintomas" => "1", "sintomas" => %w[1 2], "detalhe_febre" => "38 graus" }

    assert_equal completas, definicao.normalizar(completas)
    assert_equal({ "tem_sintomas" => "0" }, definicao.normalizar(completas.merge("tem_sintomas" => "0")))
    assert_equal({ "tem_sintomas" => "1", "sintomas" => %w[2] }, definicao.normalizar(completas.merge("sintomas" => %w[2])))
    # Obrigatória só quando aparece
    assert_equal [ "é obrigatória" ], erros_de_resposta(definicao, completas.except("detalhe_febre"))["detalhe_febre"]
    assert_empty erros_de_resposta(definicao, "tem_sintomas" => "0")
  end

  test "resposta de pergunta escondida, se chegar sem normalizar, é recusada" do
    definicao = definicao_com([ unica("pai", %w[1 2]), texto("filho", **condicao("pai", "1")) ])

    assert_equal [ "não se aplica com a resposta dada a “Pai”" ], definicao.validar("pai" => "2", "filho" => "x")["filho"]
    assert_equal [ "não se aplica com a resposta dada a “Pai”" ], definicao.validar("filho" => "x")["filho"]
    assert_not definicao.visivel?(definicao.pergunta("filho"), "pai" => [ "1" ])
  end

  test "lista suspensa e múltipla escolha também controlam perguntas" do
    definicao = definicao_com([
      unica("via", %w[1 2], "tipo" => "lista_suspensa"), texto("qual_via", **condicao("via", "2")),
      multipla("exames", %w[1 2 3]), texto("outro_exame", **condicao("exames", "3"))
    ])

    assert_equal %w[via qual_via], definicao.normalizar("via" => "2", "qual_via" => "oral").keys
    assert_not definicao.normalizar("via" => "1", "qual_via" => "oral").key?("qual_via")
    assert definicao.normalizar("exames" => %w[1 3], "outro_exame" => "x").key?("outro_exame")
    assert_not definicao.normalizar("exames" => %w[1 2], "outro_exame" => "x").key?("outro_exame")
  end

  test "comparação com uma pergunta escondida não vale" do
    definicao = definicao_com([
      unica("contou", %w[0 1]), numero("contatos", **condicao("contou", "1")), numero("avaliados", "nao_maior_que" => "contatos")
    ])

    assert_match "não pode ser maior que", erros_de_resposta(definicao, "contou" => "1", "contatos" => "2", "avaliados" => "5")["avaliados"].first
    assert_empty erros_de_resposta(definicao, "contou" => "0", "contatos" => "2", "avaliados" => "5")
  end

  private

  def validar(entrada)
    @formulario.validar(@formulario.normalizar(entrada))
  end

  def numeros_com(obrigatoria:)
    @formulario.perguntas.select { |pergunta| pergunta.obrigatoria == obrigatoria }.map(&:numero)
  end

  def definicao_com(perguntas)
    DefinicaoDeFormulario.new(estrutura_de_formulario(perguntas))
  end

  def erros_de_resposta(definicao, entrada)
    definicao.validar(definicao.normalizar(entrada))
  end

  def assert_recusada(estrutura, trecho, rascunho: false)
    erro = assert_raises(DefinicaoDeFormulario::DefinicaoInvalida, "esperava recusar por “#{trecho}”") do
      DefinicaoDeFormulario.new(estrutura, rascunho:)
    end
    mensagens = erro.erros.map(&:mensagem)
    assert mensagens.any? { |mensagem| mensagem.include?(trecho) }, "esperava “#{trecho}”, veio: #{mensagens.inspect}"
  end

  def texto(chave, extras = {}, **outros)
    { "chave" => chave, "texto" => chave.humanize, "tipo" => "texto" }.merge(extras).merge(outros.stringify_keys)
  end

  def numero(chave, extras = {}, **outros) = texto(chave, { "tipo" => "numero" }.merge(extras), **outros)
  def data(chave, extras = {}, **outros) = texto(chave, { "tipo" => "data" }.merge(extras), **outros)

  def unica(chave, codigos = %w[1 2 3], extras = {}, opcoes: nil, **outros)
    opcoes ||= codigos.map { |codigo| { "codigo" => codigo, "rotulo" => "Opção #{codigo}" } }
    texto(chave, { "tipo" => "unica", "opcoes" => opcoes }.merge(extras), **outros)
  end

  def multipla(chave, codigos = %w[1 2 3], extras = {}, opcoes: nil, **outros)
    unica(chave, codigos, { "tipo" => "multipla" }.merge(extras), opcoes:, **outros)
  end

  def condicao(pai, *valores)
    { "condicao" => { "pergunta" => pai, "valores" => valores } }
  end
end
