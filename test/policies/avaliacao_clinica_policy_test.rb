require "test_helper"

# Quem vê e quem registra cada notificação vem das liberações (Permissoes)
class AvaliacaoClinicaPolicyTest < ActiveSupport::TestCase
  TB = "seguimento_tb".freeze

  test "lista e tela de nova: consulta ou registra em algum setor" do
    assert policy(:operador, nova).index?
    assert policy(:operador, nova).new?
    assert policy(:consultor, nova).index?
    assert_not policy(:consultor, nova).new?
    assert_not policy(:sem_acesso, nova).index?
    assert_not policy(:sem_acesso, nova).new?
  end

  test "gravar: só registra no setor escolhido" do
    assert policy(:operador, nova(:ambulatorio)).create?
    assert_not policy(:operador, nova(:laboratorio)).create?
    assert_not policy(:consultor, nova(:ambulatorio)).create?
    assert_not policy(:operador, nova(nil)).create?, "sem setor não grava"
  end

  test "ver e editar: no setor da notificação" do
    do_ambulatorio = avaliacoes_clinicas(:one)
    do_laboratorio = avaliacoes_clinicas(:tres)

    assert policy(:operador, do_ambulatorio).show?
    assert policy(:operador, do_ambulatorio).update?
    assert policy(:consultor, do_ambulatorio).show?
    assert_not policy(:consultor, do_ambulatorio).update?
    assert_not policy(:operador, do_laboratorio).show?
    assert_not policy(:operador, do_laboratorio).update?
    assert policy(:laboratorista, do_laboratorio).update?
  end

  test "o admin vê e registra tudo" do
    assert policy(:admin, avaliacoes_clinicas(:tres)).update?
    assert policy(:admin, nova(:laboratorio)).create?
    assert_equal AvaliacaoClinica.count, scope(:admin).count
  end

  test "o escopo traz só os setores liberados" do
    assert_equal avaliacoes_clinicas(:one, :two).sort, scope(:operador).sort
    assert_equal avaliacoes_clinicas(:one, :two).sort, scope(:consultor).sort
    assert_equal [ avaliacoes_clinicas(:tres) ], scope(:laboratorista).to_a
    assert_empty scope(:sem_acesso)
  end

  test "ninguém exclui notificações" do
    %i[admin operador consultor laboratorista].each do |papel|
      assert_not policy(papel, avaliacoes_clinicas(:one)).destroy?, papel
    end
  end

  test "usuário não autenticado é rejeitado" do
    assert_raises(Pundit::NotAuthorizedError) { AvaliacaoClinicaPolicy.new(nil, AvaliacaoClinica) }
    assert_raises(Pundit::NotAuthorizedError) { AvaliacaoClinicaPolicy::Scope.new(nil, AvaliacaoClinica) }
  end

  private

  def nova(setor = :ambulatorio)
    AvaliacaoClinica.new(formulario: TB, setor: setor && setores(setor))
  end

  def policy(papel, record)
    AvaliacaoClinicaPolicy.new(users(papel), record)
  end

  def scope(papel)
    AvaliacaoClinicaPolicy::Scope.new(users(papel), AvaliacaoClinica).resolve
  end
end
