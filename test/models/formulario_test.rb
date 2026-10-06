require "test_helper"

class FormularioTest < ActiveSupport::TestCase
  setup { @tb = Formulario.find("seguimento_tb") }

  test "todas as definições de config/formularios carregam sem erro" do
    assert_not_empty Formulario.todos
    assert_includes Formulario.chaves, "seguimento_tb"
  end

  test "formulário inexistente vira 404" do
    assert_raises(ActiveRecord::RecordNotFound) { Formulario.find("nao_existe") }
  end

  test "seguimento de TB tem as 47 perguntas do original, com as mesmas obrigatórias" do
    assert_equal (1..47).to_a, @tb.perguntas.map(&:numero)
    assert_equal [ 4, 5, 6, 7, 8, 9, 10 ], numeros_com(obrigatoria: "abertura")
    assert_equal (11..24).to_a + [ 26, 27, 28, 30, 32, 39 ], numeros_com(obrigatoria: "encerramento")
    assert_equal %w[prontuario_sah prontuario_aghuse iniciais], @tb.perguntas_do_paciente.map(&:chave)
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
    assert_equal [ "é obrigatória para encerrar a notificação" ], erros["rx_torax"]
    assert_empty validar(respostas_de_abertura.merge(respostas_de_encerramento))
  end

  test "pergunta 10 só vale para forma clínica extrapulmonar" do
    pulmonar = @tb.normalizar(respostas_de_abertura("forma_clinica" => "1", "tb_extrapulmonar" => [ "1" ]))
    assert_not pulmonar.key?("tb_extrapulmonar")

    assert_equal [ "é obrigatória" ], validar(respostas_de_abertura("forma_clinica" => "2"))["tb_extrapulmonar"]
    assert_empty validar(respostas_de_abertura("forma_clinica" => "3", "tb_extrapulmonar" => [ "1", "10" ]))
  end

  test "a pergunta 10 é revelada pelas opções 2 e 3 da pergunta 9" do
    seguinte = @tb.condicional_seguinte(@tb.pergunta("forma_clinica"))

    assert_equal "tb_extrapulmonar", seguinte.chave
    assert_equal %w[2 3], seguinte.condicao["valores"]
  end

  test "opções exclusivas não combinam com outras" do
    assert_match "“Não” não pode ser marcada", validar(respostas_de_abertura("populacoes_especiais" => %w[0 1]))["populacoes_especiais"].first
    assert_empty validar(respostas_de_abertura("tomografia" => %w[1 3]))
    assert_not_empty validar(respostas_de_abertura("tomografia" => %w[2 1]))["tomografia"]
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
    respostas = @tb.normalizar(respostas_de_abertura("municipio_residencia" => "  Cidade   Fictícia ", "numero_contatos" => "4", "cd4_final_tratamento" => "", "comorbidades" => [ "" ]))

    assert_equal "Cidade Fictícia", respostas["municipio_residencia"]
    assert_equal 4, respostas["numero_contatos"]
    assert_equal [ "0" ], respostas["populacoes_especiais"]
    assert_not respostas.key?("cd4_final_tratamento")
    assert_not respostas.key?("comorbidades")
  end

  test "resposta formatada usa os rótulos e a data brasileira" do
    assert_equal "Pulmonar + extrapulmonar", @tb.resposta_formatada(@tb.pergunta("forma_clinica"), "3")
    assert_equal "Pleural; Ganglionar", @tb.resposta_formatada(@tb.pergunta("tb_extrapulmonar"), %w[1 2])
    assert_equal "07/01/2019", @tb.resposta_formatada(@tb.pergunta("data_encerramento"), "2019-01-07")
  end

  test "parâmetros permitidos são só as perguntas de resposta" do
    permitidos = @tb.parametros_permitidos

    assert_includes permitidos, "forma_clinica"
    assert_includes permitidos, { "tb_extrapulmonar" => [] }
    assert_not_includes permitidos, "iniciais"
  end

  test "definição com condição que não depende da pergunta anterior é recusada" do
    definicao = {
      "titulo" => "Teste",
      "secoes" => [ { "titulo" => "Única", "perguntas" => [
        { "numero" => 1, "chave" => "controle", "texto" => "Controle", "tipo" => "unica", "opcoes" => { "1" => "Sim" } },
        { "numero" => 2, "chave" => "outra", "texto" => "Outra", "tipo" => "texto" },
        { "numero" => 3, "chave" => "alvo", "texto" => "Alvo", "tipo" => "texto", "condicao" => { "pergunta" => "controle", "valores" => [ "1" ] } }
      ] } ]
    }

    assert_raises(Formulario::DefinicaoInvalida) { Formulario.new("teste", definicao) }
  end

  test "definição com tipo desconhecido é recusada" do
    definicao = { "titulo" => "Teste", "secoes" => [ { "titulo" => "Única", "perguntas" => [
      { "numero" => 1, "chave" => "campo", "texto" => "Campo", "tipo" => "arquivo" }
    ] } ] }

    assert_raises(Formulario::DefinicaoInvalida) { Formulario.new("teste", definicao) }
  end

  private

  def validar(entrada)
    @tb.validar(@tb.normalizar(entrada))
  end

  def numeros_com(obrigatoria:)
    @tb.perguntas.select { |pergunta| pergunta.obrigatoria == obrigatoria }.map(&:numero)
  end
end
