require "test_helper"

# Avisos da revisão antes de publicar: perguntas que parecem pedir um dado
# que identifica a pessoa (LGPD, art. 6º, III)
class AvisosDeMinimizacaoTest < ActiveSupport::TestCase
  test "aponta CPF, nome, endereço, telefone e afins, sem acentos e sem diferenciar maiúsculas" do
    textos = {
      "CPF do paciente" => "CPF", "Nome completo" => "nome da pessoa", "Nome da mãe" => "nome da pessoa", "Nome" => "nome da pessoa",
      "Endereço residencial" => "endereço", "CEP" => "endereço", "Telefone para contato" => "telefone", "E-mail" => "e-mail",
      "Cartão do SUS" => "Cartão Nacional de Saúde", "Número do CNS" => "Cartão Nacional de Saúde", "Data de nascimento" => "data de nascimento",
      "RG" => "documento de identidade", "Número do prontuário" => "prontuário (a identificação do paciente já pede os prontuários)"
    }
    perguntas = textos.keys.each_with_index.map { |texto, indice| { "chave" => "p#{indice}", "texto" => texto, "tipo" => "texto" } }
    avisos = AvisosDeMinimizacao.para(DefinicaoDeFormulario.new(estrutura_de_formulario(perguntas)))

    assert_equal textos.values, avisos.map(&:motivo)
  end

  test "não aponta o que é clínico, e o formulário de teste não tem nenhum aviso" do
    perguntas = [ "Peso ao nascer", "Nome do medicamento em uso", "Município de residência", "Rua da Unidade de Saúde" ]
                .each_with_index.map { |texto, indice| { "chave" => "p#{indice}", "texto" => texto, "tipo" => "texto" } }

    assert_empty AvisosDeMinimizacao.para(DefinicaoDeFormulario.new(estrutura_de_formulario(perguntas)))
    assert_empty AvisosDeMinimizacao.para(FormulariosDeTeste.acompanhamento)
  end

  test "lembra do texto livre" do
    assert AvisosDeMinimizacao.tem_texto_livre?(FormulariosDeTeste.acompanhamento)
    assert_not AvisosDeMinimizacao.tem_texto_livre?(DefinicaoDeFormulario.new(estrutura_de_formulario))
  end
end
