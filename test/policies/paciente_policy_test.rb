require "test_helper"

# Quem corrige a identificação de um paciente: quem registra todos os
# formulários em que ele tem notificação, no setor delas
class PacientePolicyTest < ActiveSupport::TestCase
  test "corrige quem registra o formulário das notificações do paciente" do
    assert policy(:operador, pacientes(:one)).update?
    assert policy(:operador, pacientes(:one)).edit?
    assert policy(:laboratorista, pacientes(:tres)).update?
    assert policy(:admin, pacientes(:tres)).update?
  end

  test "quem só consulta, é de outro setor ou não tem liberação não corrige" do
    assert_not policy(:consultor, pacientes(:one)).update?
    assert_not policy(:operador, pacientes(:tres)).update?
    assert_not policy(:laboratorista, pacientes(:one)).update?
    assert_not policy(:sem_acesso, pacientes(:one)).update?
  end

  test "com notificação num formulário que a pessoa não registra, não corrige" do
    # O paciente one passa a ter também uma notificação de outro formulário:
    # a correção mudaria o que aparece nela
    avaliacoes_clinicas(:two).update_columns(paciente_id: pacientes(:one).id, formulario: "outro_formulario")

    assert_not policy(:operador, pacientes(:one)).update?
  end

  test "paciente sem notificação não é corrigido por ninguém" do
    paciente = Paciente.create!(setor: setores(:ambulatorio), iniciais: "SN", prontuario_sah: "SAH-SEM")

    assert_not policy(:admin, paciente).update?
    assert_not policy(:operador, paciente).update?
  end

  test "ninguém vê, cria ou exclui paciente por aqui" do
    %i[admin operador].each do |papel|
      assert_not policy(papel, pacientes(:one)).show?, papel
      assert_not policy(papel, pacientes(:one)).create?, papel
      assert_not policy(papel, pacientes(:one)).destroy?, papel
    end
  end

  test "o escopo traz só os pacientes das notificações que a pessoa vê" do
    assert_equal pacientes(:one, :two).sort, scope(:operador).sort
    assert_equal pacientes(:one, :two).sort, scope(:consultor).sort
    assert_equal [ pacientes(:tres) ], scope(:laboratorista).to_a
    assert_equal Paciente.count, scope(:admin).count
    assert_empty scope(:sem_acesso)
  end

  test "usuário não autenticado é rejeitado" do
    assert_raises(Pundit::NotAuthorizedError) { PacientePolicy.new(nil, pacientes(:one)) }
    assert_raises(Pundit::NotAuthorizedError) { PacientePolicy::Scope.new(nil, Paciente) }
  end

  private

  def policy(papel, record)
    PacientePolicy.new(users(papel), record)
  end

  def scope(papel)
    PacientePolicy::Scope.new(users(papel), Paciente).resolve
  end
end
