require "test_helper"

class PacienteTest < ActiveSupport::TestCase
  test "nome, CPF e telefones ficam cifrados no banco" do
    paciente = Paciente.create!(nome: "Maria Fictícia", cpf: Cpf.gerar, numero_contatos: "(51) 99999-0000").reload

    assert_not_includes paciente.ciphertext_for(:nome), "Maria"
    assert_not_includes paciente.ciphertext_for(:cpf), paciente.cpf
    assert_not_includes paciente.ciphertext_for(:numero_contatos), "99999"
    assert_equal "Maria Fictícia", paciente.nome
  end

  # Regressão: com varchar(255), um nome de ~130 caracteres não cabia cifrado
  test "valores no limite cabem nas colunas cifradas" do
    paciente = Paciente.create!(
      nome: SecureRandom.alphanumeric(150),
      numero_contatos: Array.new(120) { %w[á é ç ã õ 1 2 3].sample }.join
    )

    assert paciente.persisted?
  end

  test "CPF é normalizado e conferido" do
    cpf = Cpf.gerar

    assert_equal cpf, Paciente.new(nome: "Teste", cpf: formatar_cpf(cpf)).cpf
    assert Paciente.new(nome: "Teste", cpf: formatar_cpf(cpf)).valid?
    assert_not Paciente.new(nome: "Teste", cpf: "abc").valid?
  end

  test "CPF é opcional, mas único" do
    assert Paciente.new(nome: "Sem CPF").valid?

    duplicado = Paciente.new(nome: "Outro", cpf: formatar_cpf(pacientes(:one).cpf))
    assert_not duplicado.valid?
    assert duplicado.errors.include?(:cpf)
  end

  test "identificar acha pelo CPF formatado ou pelo prontuário" do
    paciente = pacientes(:one)

    assert_equal paciente, Paciente.identificar(cpf: formatar_cpf(paciente.cpf), prontuario_sah: nil)
    assert_equal paciente, Paciente.identificar(cpf: "", prontuario_sah: " #{paciente.prontuario_sah} ")
    assert_nil Paciente.identificar(cpf: nil, prontuario_sah: "SAH-INEXISTENTE")
  end

  # Regressão: um CPF que normaliza para nil não pode achar paciente sem CPF
  test "identificar não confunde CPF vazio ou inválido com paciente sem CPF" do
    Paciente.create!(nome: "Paciente sem CPF")

    assert_nil Paciente.identificar(cpf: ".-", prontuario_sah: nil)
    assert_nil Paciente.identificar(cpf: "abc", prontuario_sah: nil)
  end

  test "identificar recusa CPF e prontuário de pacientes diferentes" do
    assert_raises(Paciente::IdentificadoresConflitantes) do
      Paciente.identificar(cpf: pacientes(:one).cpf, prontuario_sah: pacientes(:two).prontuario_sah)
    end
  end

  test "paciente com avaliações não pode ser apagado" do
    paciente = pacientes(:one)

    assert_not paciente.destroy
    assert Paciente.exists?(paciente.id)
  end
end
