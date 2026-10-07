require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  test "grava quem viu qual registro" do
    log = AuditLog.create!(user: users(:operador), auditable: avaliacoes_clinicas(:one), action: "show",
                           ip_address: "10.0.0.7", user_agent: "Navegador de Teste")

    assert_equal avaliacoes_clinicas(:one), log.reload.auditable
    assert_equal "AvaliacaoClinica", log.auditable_type
  end

  test "é imutável: não se altera nem se apaga" do
    log = AuditLog.create!(user: users(:operador), auditable: avaliacoes_clinicas(:one), action: "show")

    assert_raises(ActiveRecord::ReadOnlyRecord) { log.update!(action: "index") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { log.destroy }
    assert_raises(ActiveRecord::ReadOnlyRecord) { AuditLog.find(log.id).update!(user: users(:admin)) }
    assert AuditLog.exists?(log.id)
  end

  test "só as actions que exibem dado sensível" do
    log = AuditLog.new(user: users(:operador), auditable: avaliacoes_clinicas(:one), action: "destroy")

    assert_not log.valid?
    assert log.errors.include?(:action)
  end

  test "as leituras de um paciente reúnem a tela de correção e todas as notificações dele" do
    AuditLog.create!(user: users(:operador), auditable: avaliacoes_clinicas(:one), action: "show")
    AuditLog.create!(user: users(:admin), auditable: pacientes(:one), action: "edit")
    AuditLog.create!(user: users(:consultor), auditable: avaliacoes_clinicas(:two), action: "show")
    AuditLog.create!(user: users(:laboratorista), auditable: avaliacoes_clinicas(:tres), action: "show")
    AuditLog.create!(user: users(:laboratorista), auditable: pacientes(:tres), action: "edit")

    assert_equal [ users(:admin), users(:operador) ], AuditLog.do_paciente(pacientes(:one)).map(&:user)
    assert_equal [ users(:laboratorista) ], AuditLog.do_registro(avaliacoes_clinicas(:tres)).map(&:user)
  end
end
