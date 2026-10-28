require "test_helper"

# A tela de uma pergunta no gerador: o que o admin digita vira a pergunta da
# estrutura, com cada erro no seu campo
class PerguntaDoGeradorTest < ActiveSupport::TestCase
  test "opções uma por linha, no formato código, rótulo; rótulo pode ter vírgula" do
    pergunta = PerguntaDoGerador.new(texto: "Uso", tipo: "unica", opcoes: " 1 , Sim, com restrições \n\n2,Não\r\n")

    assert pergunta.valid?
    assert_equal [ { "codigo" => "1", "rotulo" => "Sim, com restrições" }, { "codigo" => "2", "rotulo" => "Não" } ], pergunta.atributos["opcoes"]
  end

  test "cada linha errada das opções é apontada" do
    pergunta = PerguntaDoGerador.new(texto: "Uso", tipo: "multipla", opcoes: "Sim\n, Vazio\n<b>, Negrito\n1, A\n1, B\n2, a", exclusivas: "1, 9")

    assert_not pergunta.valid?
    mensagens = pergunta.errors[:opcoes]
    assert_includes mensagens, "linha 1: use o formato código, rótulo (ex.: 1, Sim)"
    assert_includes mensagens, "linha 2: use o formato código, rótulo (ex.: 1, Sim)"
    assert_includes mensagens, "linha 3: o código usa até 16 letras, números, ponto, traço ou sublinhado"
    assert_includes mensagens, "há códigos repetidos"
    assert_includes mensagens, "há rótulos repetidos"
    assert_equal [ "use só códigos das opções (9 não está)" ], pergunta.errors[:exclusivas]
  end

  test "só os campos do tipo escolhido entram na pergunta" do
    campos = { texto: "Peso", limite: "50", minimo: "1", maximo: "300", decimais: "1", opcoes: "1, Sim", exclusivas: "1",
               permite_futuro: "1", nao_maior_que: "outra", nao_antes_de: "outra" }

    assert_equal({ "texto" => "Peso", "tipo" => "numero", "minimo" => 1, "maximo" => 300, "decimais" => 1, "nao_maior_que" => "outra" },
                 PerguntaDoGerador.new(**campos, tipo: "numero").atributos)
    assert_equal({ "texto" => "Peso", "tipo" => "texto", "maximo" => 50 }, PerguntaDoGerador.new(**campos, tipo: "texto").atributos)
    assert_equal({ "texto" => "Peso", "tipo" => "data", "permite_futuro" => true, "nao_antes_de" => "outra" },
                 PerguntaDoGerador.new(**campos, tipo: "data").atributos)
    assert_equal({ "texto" => "Peso", "tipo" => "lista_suspensa", "opcoes" => [ { "codigo" => "1", "rotulo" => "Sim" } ] },
                 PerguntaDoGerador.new(**campos, tipo: "lista_suspensa").atributos)
    assert_equal [ { "codigo" => "1", "rotulo" => "Sim", "exclusiva" => true } ], PerguntaDoGerador.new(**campos, tipo: "multipla").atributos["opcoes"]
  end

  test "padrões quando o campo vem em branco" do
    assert_equal 100, PerguntaDoGerador.new(texto: "A", tipo: "texto").atributos["maximo"]
    assert_equal 1000, PerguntaDoGerador.new(texto: "A", tipo: "texto_longo").atributos["maximo"]
    assert_equal({ "texto" => "A", "tipo" => "numero", "minimo" => 0, "maximo" => 100_000, "decimais" => 0 },
                 PerguntaDoGerador.new(texto: "A", tipo: "numero").atributos)
    assert_equal "texto", PerguntaDoGerador.new(texto: "A").tipo
    assert_nil PerguntaDoGerador.new(texto: "A").atributos["obrigatoria"]
  end

  test "números fora da faixa e tipos desconhecidos são apontados" do
    pergunta = PerguntaDoGerador.new(texto: "", tipo: "numero", minimo: "dez", maximo: "-5", decimais: "7")
    assert_not pergunta.valid?
    assert pergunta.errors[:texto].any?
    assert_includes pergunta.errors[:minimo], "use um número inteiro de -1000000000 a 1000000000"
    assert_includes pergunta.errors[:decimais], "use um número inteiro de 0 a 3"

    assert_includes PerguntaDoGerador.new(texto: "A", tipo: "numero", minimo: "10", maximo: "5").tap(&:valid?).errors[:maximo], "não pode ser menor que o mínimo"
    assert_includes PerguntaDoGerador.new(texto: "A", tipo: "texto", limite: "201").tap(&:valid?).errors[:limite], "use um número inteiro de 1 a 200"
    assert_includes PerguntaDoGerador.new(texto: "A", tipo: "arquivo").tap(&:valid?).errors[:tipo], "escolha um tipo da lista"
    assert_includes PerguntaDoGerador.new(texto: "A", obrigatoria: "talvez").tap(&:valid?).errors[:obrigatoria], "escolha uma das opções"
  end

  test "com numeração manual, o número é obrigatório" do
    assert_not PerguntaDoGerador.new(texto: "A", numeracao_manual: true).valid?
    assert_not PerguntaDoGerador.new(texto: "A", numero: "1 2", numeracao_manual: true).valid?
    pergunta = PerguntaDoGerador.new(texto: "A", numero: " 7a ", numeracao_manual: true)
    assert pergunta.valid?
    assert_equal "7a", pergunta.atributos["numero"]
    assert_nil PerguntaDoGerador.new(texto: "A", numero: "7").atributos["numero"]
  end

  test "pergunta dependente precisa de opções da controladora" do
    controladora = FormulariosDeTeste.acompanhamento.pergunta("forma")

    assert_includes PerguntaDoGerador.new(texto: "A", controladora:, valores: [ "" ]).tap(&:valid?).errors[:valores],
                    "escolha pelo menos uma opção que mostra esta pergunta"
    assert_includes PerguntaDoGerador.new(texto: "A", controladora:, valores: [ "9" ]).tap(&:valid?).errors[:valores],
                    "escolha só opções da pergunta “Forma”"
    assert PerguntaDoGerador.new(texto: "A", controladora:, valores: %w[2 3]).valid?
    assert_equal %w[2 3], PerguntaDoGerador.new(texto: "A", controladora:, valores: [ "", "2", "3", "2" ]).valores
  end

  test "a tela de edição volta exatamente a pergunta gravada" do
    definicao = FormulariosDeTeste.acompanhamento
    definicao.perguntas.each do |pergunta|
      tela = PerguntaDoGerador.de(pergunta, numeracao_manual: true, controladora: definicao.controladora(pergunta))
      assert tela.valid?, "#{pergunta.chave}: #{tela.errors.full_messages}"
      original = definicao.estrutura["secoes"].flat_map { |secao| secao["perguntas"] }.find { |gravada| gravada["chave"] == pergunta.chave }
      assert_equal original.except("chave", "condicao"), tela.atributos, pergunta.chave
    end
  end
end
