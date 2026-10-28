ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "formularios_de_teste"

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

    # Respostas mínimas válidas do acompanhamento de teste (só a abertura), no formato
    # em que chegam do navegador
    def respostas_de_abertura(**outras)
      {
        "numero_registro" => "1234567", "gestante" => "6", "populacoes_especiais" => [ "", "0" ],
        "recebe_beneficio" => "0", "municipio_residencia" => "Cidade Fictícia", "forma" => "1"
      }.merge(outras.stringify_keys)
    end

    # Estrutura mínima válida de um formulário (DefinicaoDeFormulario), com
    # as perguntas dadas numa seção só. campos troca ou acrescenta campos do formulário.
    def estrutura_de_formulario(perguntas = [ { "chave" => "campo", "texto" => "Campo", "tipo" => "texto" } ], **campos)
      { "titulo" => "Formulário de teste", "finalidade" => "testar o sistema", "base_legal" => "nenhuma, é um teste",
        "secoes" => [ { "id" => "s1", "titulo" => "Única", "perguntas" => perguntas } ] }.merge(campos.stringify_keys)
    end

    # A instituição e o setor do formulário criado pelo gerador nos testes
    def destino_do_formulario
      { instituicao_id: instituicoes(:centro).id, setor_ids: [ setores(:ambulatorio).id ] }
    end

    # Cria e publica um formulário (pelo admin), como o gerador faz
    def publicar_formulario(chave, estrutura = estrutura_de_formulario)
      formulario = Formulario.create!(chave:, instituicao: instituicoes(:centro))
      formulario.versoes.create!(numero: 1, estrutura:).publicar!(por: users(:admin))
      formulario.reload
    end

    # Todas as obrigatórias "para encerrar" respondidas
    def respostas_de_encerramento
      chaves = FormulariosDeTeste.acompanhamento.perguntas.select { |pergunta| pergunta.obrigatoria == "encerramento" }.map(&:chave)
      chaves.index_with { |chave| chave == "mudanca_tratamento" ? "0" : "3" }
            .merge("outro_material" => "0", "data_encerramento" => Date.current.iso8601)
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
