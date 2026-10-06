require "test_helper"

class CpfTest < ActiveSupport::TestCase
  test "normalizar remove só a pontuação" do
    # Dígitos verificadores inválidos de propósito: nenhum CPF válido no repositório
    assert_equal "12345678900", Cpf.normalizar(" 123.456.789-00 ")
    assert_equal "abc", Cpf.normalizar("abc")
    assert_nil Cpf.normalizar(".-")
    assert_nil Cpf.normalizar(nil)
  end

  # Confere contra uma segunda implementação da regra, para não versionar CPFs
  test "valido? confere os dígitos verificadores" do
    20.times do
      base = Array.new(9) { rand(10) }.join
      next if base.squeeze.length == 1

      d1 = digito_verificador(base)
      d2 = digito_verificador("#{base}#{d1}")

      assert Cpf.valido?("#{base}#{d1}#{d2}")
      assert_not Cpf.valido?("#{base}#{d1}#{(d2 + 1) % 10}")
    end
  end

  test "valido? rejeita formato errado e dígitos repetidos" do
    assert_not Cpf.valido?("111.111.111-11") # dígitos verificadores batem, mas é inválido
    assert_not Cpf.valido?("1234567890")
    assert_not Cpf.valido?("123456789012")
    assert_not Cpf.valido?("abc")
    assert_not Cpf.valido?(nil)
  end

  test "gerar produz CPFs válidos" do
    10.times { assert Cpf.valido?(Cpf.gerar) }
  end

  private

  # Regra da Receita Federal: resto da soma ponderada por 11; abaixo de 2 vira 0
  def digito_verificador(numeros)
    soma = numeros.chars.each_with_index.sum { |numero, i| numero.to_i * (numeros.length + 1 - i) }
    resto = soma % 11
    resto < 2 ? 0 : 11 - resto
  end
end
