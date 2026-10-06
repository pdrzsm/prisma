require "test_helper"

class AvaliacaoClinicaTest < ActiveSupport::TestCase
  test "aceita textos, números, booleanos, nulos e listas" do
    assert avaliacao("tosse" => "sim", "dias_de_tosse" => 21, "febre" => false, "hiv" => nil, "sintomas" => [ "febre", "sudorese" ]).valid?
  end

  test "respostas ficam cifradas no banco e voltam iguais" do
    registro = avaliacao("hiv" => "positivo")
    registro.save!

    assert_not_includes registro.reload.ciphertext_for(:dados_formulario), "positivo"
    assert_equal({ "hiv" => "positivo" }, registro.dados_formulario)
  end

  test "rejeita formulário vazio ou que não seja um conjunto de campos" do
    assert_not avaliacao({}).valid?
    assert_not avaliacao("texto solto").valid?
  end

  test "rejeita estrutura aninhada e nomes de campo inválidos" do
    assert_not avaliacao("grupo" => { "campo" => "x" }).valid?
    assert_not avaliacao("lista" => [ { "campo" => "x" } ]).valid?
    assert_not avaliacao("Campo Inválido" => "x").valid?
  end

  test "rejeita campos demais ou conteúdo grande demais" do
    assert_not avaliacao((1..301).to_h { |i| [ "campo_#{i}", "x" ] }).valid?
    assert_not avaliacao("observacoes" => "x" * 70_000).valid?
  end

  private

  def avaliacao(dados)
    AvaliacaoClinica.new(paciente: pacientes(:one), user: users(:operador), dados_formulario: dados)
  end
end
