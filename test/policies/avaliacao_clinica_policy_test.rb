require "test_helper"

class AvaliacaoClinicaPolicyTest < ActiveSupport::TestCase
  PAPEIS = %i[operador consultor admin].freeze

  test "operador e admin registram avaliações" do
    assert policy(:operador).create?
    assert policy(:admin).create?
  end

  test "consultor não registra avaliações" do
    assert_not policy(:consultor).new?
    assert_not policy(:consultor).create?
  end

  test "todos os papéis visualizam todas as avaliações" do
    PAPEIS.each do |papel|
      assert policy(papel).index?, "#{papel} deveria listar"
      assert policy(papel).show?, "#{papel} deveria visualizar"
      assert_equal AvaliacaoClinica.count, scope(papel).count, "#{papel} deveria ver todas"
    end
  end

  test "ninguém edita nem exclui avaliações" do
    PAPEIS.each do |papel|
      assert_not policy(papel).update?, "#{papel} não deveria editar"
      assert_not policy(papel).destroy?, "#{papel} não deveria excluir"
    end
  end

  test "usuário não autenticado é rejeitado" do
    assert_raises(Pundit::NotAuthorizedError) { AvaliacaoClinicaPolicy.new(nil, AvaliacaoClinica) }
    assert_raises(Pundit::NotAuthorizedError) { AvaliacaoClinicaPolicy::Scope.new(nil, AvaliacaoClinica) }
  end

  private

  def policy(papel)
    AvaliacaoClinicaPolicy.new(users(papel), AvaliacaoClinica)
  end

  def scope(papel)
    AvaliacaoClinicaPolicy::Scope.new(users(papel), AvaliacaoClinica).resolve
  end
end
