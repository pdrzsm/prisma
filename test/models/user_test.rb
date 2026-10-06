require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "admin? é verdadeiro só para admin" do
    user = users(:admin)

    assert user.admin?
    assert_not user.operador?
    assert_not user.consultor?
  end

  test "operador? é verdadeiro só para operador" do
    user = users(:operador)

    assert user.operador?
    assert_not user.admin?
    assert_not user.consultor?
  end

  test "consultor? é verdadeiro só para consultor" do
    user = users(:consultor)

    assert user.consultor?
    assert_not user.admin?
    assert_not user.operador?
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
    user = User.new(username: "novo", cpf: Cpf.gerar, role: "operador")

    user.password = user.password_confirmation = "curta-123"
    assert_not user.valid?
    assert user.errors.include?(:password)

    user.password = user.password_confirmation = "uma-senha-longa-o-bastante"
    assert user.valid?
  end
end
