require "test_helper"

class ConfiguracaoPolicyTest < ActiveSupport::TestCase
  ACOES = %i[index? new? create? edit? update? destroy?].freeze

  test "só o admin administra instituições e setores" do
    { admin: true, operador: false, consultor: false }.each do |papel, pode|
      policies = [ InstituicaoPolicy.new(users(papel), instituicoes(:centro)),
                   SetorPolicy.new(users(papel), setores(:ambulatorio)) ]
      policies.product(ACOES).each do |policy, acao|
        assert_equal pode, policy.public_send(acao), "#{papel}: #{policy.class}##{acao}"
      end
    end
  end

  test "a lista só traz registros para o admin" do
    assert_equal Instituicao.count, Pundit.policy_scope!(users(:admin), Instituicao).count
    assert_empty Pundit.policy_scope!(users(:operador), Instituicao)
    assert_empty Pundit.policy_scope!(users(:consultor), Setor)
  end
end
