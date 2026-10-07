ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Senha de todos os usuários de test/fixtures/users.yml
    SENHA_DE_TESTE = "senha-de-teste-123"

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # CPF com pontuação, como um operador digitaria
    def formatar_cpf(cpf)
      cpf.sub(/\A(\d{3})(\d{3})(\d{3})(\d{2})\z/, '\1.\2.\3-\4')
    end

    # Respostas mínimas válidas do seguimento de TB (só a abertura), no formato
    # em que chegam do navegador
    def respostas_de_abertura(**outras)
      {
        "numero_sinan" => "1234567", "gestante" => "6", "populacoes_especiais" => [ "", "0" ],
        "recebe_beneficio" => "0", "municipio_residencia" => "Cidade Fictícia", "forma_clinica" => "1"
      }.merge(outras.stringify_keys)
    end

    # Todas as obrigatórias "para encerrar" respondidas
    def respostas_de_encerramento
      chaves = Formulario.find("seguimento_tb").perguntas.select { |pergunta| pergunta.obrigatoria == "encerramento" }.map(&:chave)
      chaves.index_with { |chave| chave == "mudanca_esquema" ? "0" : "3" }
            .merge("outro_material" => "0", "data_encerramento" => Date.current.iso8601)
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
