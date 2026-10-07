require "test_helper"

class AvaliacaoClinicaTest < ActiveSupport::TestCase
  test "respostas são normalizadas, cifradas no banco e voltam iguais" do
    registro = avaliacao(respostas_de_abertura("municipio_residencia" => "Município Secreto"))
    registro.save!

    assert_not_includes registro.reload.ciphertext_for(:dados_formulario), "Município Secreto"
    assert_equal "Município Secreto", registro.respostas["municipio_residencia"]
    assert_equal [ "0" ], registro.respostas["populacoes_especiais"]
  end

  test "valida contra a definição do formulário, com erros por pergunta" do
    registro = avaliacao(respostas_de_abertura.except("forma_clinica"))

    assert_not registro.valid?
    assert_equal [ "é obrigatória" ], registro.erros_da_pergunta("forma_clinica")
    assert_includes registro.errors.full_messages, "9. Forma clínica: é obrigatória"
  end

  test "formulário desconhecido é recusado" do
    registro = avaliacao(respostas_de_abertura)
    registro.formulario = "nao_existe"

    assert_not registro.valid?
    assert registro.errors.include?(:formulario)
  end

  test "fica encerrada quando a data de encerramento é preenchida" do
    registro = avaliacao(respostas_de_abertura.merge(respostas_de_encerramento))

    assert registro.valid?
    assert registro.encerrada?
    assert_not avaliacoes_clinicas(:one).encerrada?
  end

  test "edições simultâneas não se sobrescrevem sem aviso" do
    primeira = AvaliacaoClinica.find(avaliacoes_clinicas(:one).id)
    segunda = AvaliacaoClinica.find(avaliacoes_clinicas(:one).id)

    primeira.update!(dados_formulario: primeira.respostas.merge("numero_contatos" => 3))
    assert_raises(ActiveRecord::StaleObjectError) do
      segunda.update!(dados_formulario: segunda.respostas.merge("numero_contatos" => 4))
    end
  end

  test "cada alteração fica na auditoria, com as respostas cifradas" do
    registro = avaliacoes_clinicas(:one)

    assert_difference -> { registro.versions.count }, 1 do
      registro.update!(dados_formulario: registro.respostas.merge("baciloscopia_escarro_mes_1" => "2"))
    end
    assert_not_includes registro.versions.last.object_changes, "Cidade Fictícia"
  end

  test "o setor é o mesmo do paciente" do
    registro = avaliacao(respostas_de_abertura)
    registro.setor = setores(:laboratorio)

    assert_not registro.valid?
    assert_includes registro.errors[:setor], "é diferente do setor do paciente"
  end

  test "só registra em setor com o formulário habilitado" do
    formularios_habilitados(:tb_ambulatorio).delete
    registro = avaliacao(respostas_de_abertura)

    assert_not registro.valid?
    assert_includes registro.errors[:formulario], "não está habilitado neste setor"
  end

  test "o setor não muda depois do registro" do
    assert_raises(ActiveRecord::ReadonlyAttributeError) { avaliacoes_clinicas(:one).setor = setores(:laboratorio) }
  end

  test "o registro grava a finalidade e a base legal do formulário, que não mudam depois" do
    tb = Formulario.find("seguimento_tb")
    registro = avaliacao(respostas_de_abertura)
    registro.finalidade = "outra finalidade qualquer"
    registro.save!

    assert_equal [ tb.finalidade, tb.base_legal ], [ registro.reload.finalidade, registro.base_legal ]
    assert_raises(ActiveRecord::ReadonlyAttributeError) { registro.finalidade = "mudada depois" }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { registro.base_legal = "mudada depois" }
  end

  private

  def avaliacao(respostas)
    AvaliacaoClinica.new(formulario: "seguimento_tb", setor: setores(:ambulatorio), paciente: pacientes(:one),
                         user: users(:operador), dados_formulario: respostas)
  end
end
