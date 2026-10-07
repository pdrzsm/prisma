require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "o papel global é admin ou usuario" do
    assert users(:admin).admin?
    assert_not users(:admin).usuario?
    assert users(:operador).usuario?
    assert_not users(:operador).admin?
  end

  test "os papéis antigos (operador, consultor) não existem mais" do
    %w[operador consultor recepcao].each do |papel|
      user = User.new(role: papel)

      assert_not user.valid?, papel
      assert user.errors.include?(:role), papel
    end
  end

  test "só existe uma conta admin: a validação recusa a segunda" do
    segundo = usuario_novo(role: "admin")

    assert_not segundo.valid?
    assert_includes segundo.errors[:role], "admin já existe: o sistema tem uma só conta admin"
  end

  test "o banco também recusa a segunda conta admin, mesmo sem validação" do
    assert_raises(ActiveRecord::RecordNotUnique) { usuario_novo(role: "admin").save!(validate: false) }
    assert_raises(ActiveRecord::RecordNotUnique) { users(:operador).update_columns(role: "admin") }
  end

  test "a conta admin não pode ser desativada" do
    admin = users(:admin)
    admin.ativo = false

    assert_not admin.valid?
    assert_includes admin.errors[:ativo], "a conta admin não pode ser desativada"
  end

  test "conta desativada não entra" do
    user = users(:operador)
    assert user.active_for_authentication?

    user.update!(ativo: false)
    assert_not user.active_for_authentication?
    assert_equal :desativada, user.inactive_message
  end

  test "nome é obrigatório" do
    user = usuario_novo(nome: " ")

    assert_not user.valid?
    assert user.errors.include?(:nome)
  end

  # Regressão: o mapeamento inteiro numa coluna string fazia "2" ser lido como role nil
  test "papel é gravado como texto explícito e relido do banco" do
    user = users(:admin).reload

    assert_equal "admin", user.role_before_type_cast
    assert_equal "admin", user.role
  end

  test "papel é obrigatório" do
    user = User.new

    assert_nil user.role
    assert_not user.valid?
    assert user.errors.include?(:role)
  end

  test "papel fora da lista é rejeitado na validação" do
    user = User.new(role: "recepcao")

    assert_not user.valid?
    assert user.errors.include?(:role)
  end

  test "login por username (qualquer caixa) ou por CPF com ou sem pontuação" do
    user = users(:operador)

    assert_equal user, User.find_for_database_authentication(login: "OPERADOR_teste")
    assert_equal user, User.find_for_database_authentication(login: user.cpf)
    assert_equal user, User.find_for_database_authentication(login: formatar_cpf(user.cpf))
    assert_nil User.find_for_database_authentication(login: ".-")
    assert_nil User.find_for_database_authentication(login: "")
  end

  test "CPF do usuário fica cifrado no banco" do
    user = users(:operador).reload

    assert_not_includes user.ciphertext_for(:cpf), user.cpf
  end

  test "senha precisa de pelo menos 12 caracteres" do
    user = usuario_novo

    user.password = user.password_confirmation = "curta-123"
    assert_not user.valid?
    assert user.errors.include?(:password)

    user.password = user.password_confirmation = "uma-senha-longa-o-bastante"
    assert user.valid?
  end

  private

  def usuario_novo(**atributos)
    User.new(nome: "Pessoa Nova", username: "novo", cpf: Cpf.gerar, role: "usuario",
             password: "uma-senha-longa-o-bastante", **atributos)
  end
end
