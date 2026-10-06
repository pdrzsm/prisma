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
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
