require "test_helper"

class PacienteTest < ActiveSupport::TestCase
  test "iniciais são normalizadas e, como os prontuários, ficam cifradas no banco" do
    paciente = Paciente.create!(iniciais: "a. b. c. d. e. f. g. h. i. j.", prontuario_sah: " SAH-9999 ").reload

    assert_equal "ABCDEFGHIJ", paciente.iniciais
    assert_equal "SAH-9999", paciente.prontuario_sah
    assert_not_includes paciente.ciphertext_for(:iniciais), "ABCDEFGHIJ"
    assert_not_includes paciente.ciphertext_for(:prontuario_sah), "SAH-9999"
  end

  test "iniciais são obrigatórias e curtas" do
    assert_not Paciente.new(iniciais: "").valid?
    assert_not Paciente.new(iniciais: "ABCDEFGHIJK").valid?
    assert Paciente.new(iniciais: "MSS").valid?
  end

  test "prontuário pertence a um só paciente" do
    duplicado = Paciente.new(iniciais: "XYZ", prontuario_sah: pacientes(:one).prontuario_sah)

    assert_not duplicado.valid?
    assert duplicado.errors.include?(:prontuario_sah)
  end

  test "identificar acha pelo prontuário SAH ou AGHUSE quando as iniciais conferem" do
    paciente = pacientes(:one)

    assert_equal paciente, Paciente.identificar(prontuario_sah: " SAH-0001 ", prontuario_aghuse: "", iniciais: "m.f.u")
    assert_equal paciente, Paciente.identificar(prontuario_sah: nil, prontuario_aghuse: "AGH-0001", iniciais: "MFU")
    assert_nil Paciente.identificar(prontuario_sah: "SAH-NOVO", prontuario_aghuse: nil, iniciais: "MFU")
    assert_nil Paciente.identificar(prontuario_sah: "", prontuario_aghuse: "", iniciais: "MFU")
  end

  test "prontuário digitado com outra caixa ou com espaços é o mesmo prontuário" do
    paciente = pacientes(:one)

    assert_equal paciente, Paciente.identificar(prontuario_sah: "sah - 0001", prontuario_aghuse: nil, iniciais: "MFU")
    assert_not Paciente.new(iniciais: "XYZ", prontuario_sah: "sah-0001").valid?
  end

  test "identificar recusa prontuários de pacientes diferentes" do
    erro = assert_raises(Paciente::IdentificacaoInvalida) do
      Paciente.identificar(prontuario_sah: "SAH-0001", prontuario_aghuse: "AGH-0002", iniciais: "MFU")
    end

    assert_match "pacientes diferentes", erro.message
  end

  test "identificar recusa prontuário que não confere com o cadastro" do
    assert_raises(Paciente::IdentificacaoInvalida) do
      Paciente.identificar(prontuario_sah: "SAH-0001", prontuario_aghuse: "AGH-DIGITADO-ERRADO", iniciais: "MFU")
    end
  end

  test "identificar recusa iniciais que não conferem ou em branco" do
    assert_match "não conferem", assert_raises(Paciente::IdentificacaoInvalida) {
      Paciente.identificar(prontuario_sah: "SAH-0001", prontuario_aghuse: nil, iniciais: "XYZ")
    }.message
    assert_match "Informe as iniciais", assert_raises(Paciente::IdentificacaoInvalida) {
      Paciente.identificar(prontuario_sah: "SAH-0001", prontuario_aghuse: nil, iniciais: " ")
    }.message
  end

  test "paciente com avaliações não pode ser apagado" do
    paciente = pacientes(:one)

    assert_not paciente.destroy
    assert Paciente.exists?(paciente.id)
  end
end
