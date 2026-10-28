require "test_helper"

# O que muda de uma versão do formulário para a outra, na revisão antes de publicar
class ComparacaoDeVersoesTest < ActiveSupport::TestCase
  setup { @anterior = FormulariosDeTeste.acompanhamento }

  test "primeira versão: tudo é novo" do
    comparacao = ComparacaoDeVersoes.new(nil, @anterior)

    assert comparacao.primeira_versao?
    assert_equal @anterior.perguntas, comparacao.novas
    assert_empty comparacao.removidas
    assert_not comparacao.sem_mudancas?
  end

  test "versão igual não tem mudanças" do
    assert ComparacaoDeVersoes.new(@anterior, @anterior).sem_mudancas?
  end

  test "perguntas novas, removidas e alteradas, opção por opção, e o cabeçalho" do
    estrutura = @anterior.estrutura.deep_dup
    perguntas = estrutura["secoes"].flat_map { |secao| secao["perguntas"] }
    gestante = perguntas.find { |pergunta| pergunta["chave"] == "gestante" }
    gestante["texto"] = "Está gestante?"
    gestante["opcoes"] = gestante["opcoes"].reject { |opcao| opcao["codigo"] == "9" }
    gestante["opcoes"].find { |opcao| opcao["codigo"] == "5" }["rotulo"] = "Não está"
    gestante["opcoes"] << { "codigo" => "7", "rotulo" => "Não sabe" }
    estrutura["secoes"].first["perguntas"] << { "chave" => "nova", "numero" => "48", "texto" => "Nova", "tipo" => "texto" }
    estrutura["secoes"].each { |secao| secao["perguntas"].reject! { |pergunta| pergunta["chave"] == "cultura" } }
    estrutura["finalidade"] = "outra finalidade"

    comparacao = ComparacaoDeVersoes.new(@anterior, DefinicaoDeFormulario.new(estrutura))
    assert_equal %w[nova], comparacao.novas.map(&:chave)
    assert_equal %w[cultura], comparacao.removidas.map(&:chave)
    assert_equal [ "finalidade" ], comparacao.cabecalho
    alteracao = comparacao.alteradas.sole
    assert_equal "gestante", alteracao.pergunta.chave
    assert_equal [ "enunciado", "opção nova: 7, Não sabe", "opção removida: 9, Ignorado", "opção 5 renomeada: “Não” → “Não está”" ],
                 alteracao.mudancas
  end

  test "remover uma pergunta não marca as seguintes como alteradas só porque o número automático mudou" do
    estrutura = DefinicaoDeFormulario.new(estrutura_de_formulario(%w[um dois tres].map { |chave| { "chave" => chave, "texto" => chave, "tipo" => "texto" } })).estrutura
    sem_a_primeira = estrutura.deep_dup.tap { |copia| copia["secoes"].first["perguntas"].shift }

    comparacao = ComparacaoDeVersoes.new(DefinicaoDeFormulario.new(estrutura), DefinicaoDeFormulario.new(sem_a_primeira))
    assert_equal %w[um], comparacao.removidas.map(&:chave)
    assert_empty comparacao.alteradas

    # Na numeração manual, o número é do admin: a troca aparece
    manual = @anterior.estrutura.deep_dup
    manual["secoes"].first["perguntas"].first["numero"] = "3a"
    assert_equal [ "número" ], ComparacaoDeVersoes.new(@anterior, DefinicaoDeFormulario.new(manual)).alteradas.sole.mudancas
  end

  test "tipo, obrigatoriedade, condição e limites também contam" do
    estrutura = @anterior.estrutura.deep_dup
    perguntas = estrutura["secoes"].flat_map { |secao| secao["perguntas"] }
    perguntas.find { |pergunta| pergunta["chave"] == "numero_registro" }.merge!("tipo" => "texto_longo", "maximo" => 40)
    perguntas.find { |pergunta| pergunta["chave"] == "locais" }["condicao"]["valores"] = [ "2" ]
    perguntas.find { |pergunta| pergunta["chave"] == "gestante" }.delete("obrigatoria")
    estrutura["lista"] = %w[forma]

    mudancas = ComparacaoDeVersoes.new(@anterior, DefinicaoDeFormulario.new(estrutura)).alteradas.to_h { |alteracao| [ alteracao.pergunta.chave, alteracao.mudancas ] }
    assert_equal [ "tipo (Texto curto → Texto longo)", "máximo" ], mudancas["numero_registro"]
    assert_equal [ "condição" ], mudancas["locais"]
    assert_equal [ "obrigatoriedade" ], mudancas["gestante"]
  end
end
