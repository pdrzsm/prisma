require "test_helper"

class SetorTest < ActiveSupport::TestCase
  test "nome não repete na mesma instituição, sem diferenciar maiúsculas" do
    repetido = instituicoes(:centro).setores.build(nome: " ambulatório ")

    assert_not repetido.valid?
    assert_includes repetido.errors[:nome], "já está em uso"
  end

  test "o mesmo nome pode existir em outra instituição" do
    assert instituicoes(:hospital).setores.create(nome: "Ambulatório").persisted?
  end

  test "precisa de instituição e de nome" do
    setor = Setor.new(nome: " ")

    assert_not setor.valid?
    assert_includes setor.errors[:instituicao], "precisa existir"
    assert_includes setor.errors[:nome], "não pode ficar em branco"
  end
end
