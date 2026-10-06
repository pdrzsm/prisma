require "test_helper"

class AvaliacoesClinicasControllerTest < ActionDispatch::IntegrationTest
  test "operador e admin abrem o formulário; consultor não" do
    %i[operador admin].each do |papel|
      sign_in users(papel)
      get new_avaliacao_clinica_path

      assert_response :success, papel
    end

    sign_in users(:consultor)
    get new_avaliacao_clinica_path

    assert_redirected_to root_path
  end

  test "cria paciente e avaliação, registra o autor e audita sem texto puro" do
    sign_in users(:operador)
    cpf = Cpf.gerar

    assert_difference [ "Paciente.count", "AvaliacaoClinica.count" ], 1 do
      enviar paciente: { cpf: formatar_cpf(cpf), nome: "Paciente Novo" }
    end

    assert_redirected_to root_path
    avaliacao = AvaliacaoClinica.last
    assert_equal users(:operador), avaliacao.user
    assert_equal cpf, avaliacao.paciente.cpf
    assert_equal users(:operador).id.to_s, avaliacao.versions.last.whodunnit

    auditoria = avaliacao.paciente.versions.last.object_changes
    assert_not_includes auditoria, cpf
    assert_not_includes auditoria, "Paciente Novo"
  end

  # Regressão: o fluxo antigo sobrescrevia o cadastro de quem tivesse o CPF enviado
  test "paciente existente é só vinculado: o cadastro não é sobrescrito" do
    sign_in users(:operador)
    paciente = pacientes(:one)
    nome_original = paciente.nome

    assert_no_difference "Paciente.count" do
      assert_difference "paciente.avaliacoes_clinicas.count", 1 do
        enviar paciente: { cpf: formatar_cpf(paciente.cpf), nome: "Nome Trocado", numero_contatos: "000" }
      end
    end

    assert_equal nome_original, paciente.reload.nome
    assert_match "não foram alterados", flash[:notice]
  end

  test "CPF e prontuário de pacientes diferentes são recusados" do
    sign_in users(:operador)

    assert_no_difference [ "Paciente.count", "AvaliacaoClinica.count" ] do
      enviar paciente: { cpf: pacientes(:one).cpf, prontuario_sah: pacientes(:two).prontuario_sah }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "pacientes diferentes"
  end

  test "formulário fora do formato não grava nada" do
    sign_in users(:operador)

    assert_no_difference [ "Paciente.count", "AvaliacaoClinica.count" ] do
      enviar dados: { "grupo" => { "aninhado" => "x" } }
    end

    assert_response :unprocessable_content
  end

  test "consultor não grava" do
    sign_in users(:consultor)

    assert_no_difference [ "Paciente.count", "AvaliacaoClinica.count" ] do
      enviar paciente: { cpf: Cpf.gerar }
    end

    assert_redirected_to root_path
    assert_equal "Você não tem permissão para realizar esta ação.", flash[:alert]
  end

  test "dados do paciente e do formulário não vão para o log" do
    sign_in users(:operador)
    enviar paciente: { cpf: Cpf.gerar, nome: "Nome Que Não Pode Vazar" }, dados: { "hiv" => "positivo" }

    assert_equal "[FILTERED]", request.filtered_parameters["paciente"]
    assert_equal "[FILTERED]", request.filtered_parameters["avaliacao_clinica"]
  end

  private

  def enviar(paciente: {}, dados: { "tosse" => "sim" })
    post avaliacoes_clinicas_path, params: {
      paciente: { nome: "Paciente Novo" }.merge(paciente),
      avaliacao_clinica: { dados_formulario: dados }
    }
  end
end
