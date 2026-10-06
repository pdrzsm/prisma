# Normalização e validação de CPF (Cadastro de Pessoas Físicas).
module Cpf
  module_function

  # Remove só a pontuação. Letras e outros caracteres continuam no valor
  # para a validação rejeitar a entrada, em vez de virar nil em silêncio.
  def normalizar(valor)
    valor.to_s.gsub(/[\s.\-\/]/, "").presence
  end

  def valido?(valor)
    digitos = normalizar(valor).to_s
    return false unless digitos.match?(/\A\d{11}\z/)
    return false if digitos.squeeze.length == 1 # 000.000.000-00, 111..., etc.

    digitos[9, 2] == digitos_verificadores(digitos[0, 9])
  end

  # CPF aleatório com dígitos verificadores válidos, para seeds e testes.
  # Nunca versione CPFs reais. SecureRandom, e não rand: o rand segue a
  # semente fixa dos testes e repetiria CPFs entre fixtures e testes.
  def gerar
    loop do
      cpf = Array.new(9) { SecureRandom.random_number(10) }.join.then { |base| base + digitos_verificadores(base) }
      return cpf if valido?(cpf)
    end
  end

  def digitos_verificadores(base)
    numeros = base.chars.map(&:to_i)
    2.times do
      soma = numeros.each_with_index.sum { |numero, i| numero * (numeros.length + 1 - i) }
      numeros << soma * 10 % 11 % 10
    end
    numeros.last(2).join
  end
end
