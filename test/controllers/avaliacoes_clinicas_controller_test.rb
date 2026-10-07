require "test_helper"

class AvaliacoesClinicasControllerTest < ActionDispatch::IntegrationTest
  FORMULARIO = "seguimento_tb".freeze

  test "exige login" do
    get formulario_avaliacoes_clinicas_path(FORMULARIO)

    assert_redirected_to new_user_session_path
  end

  test "formulário inexistente dá 404" do
    sign_in users(:operador)
    get formulario_avaliacoes_clinicas_path("nao_existe")

    assert_response :not_found
  end

  test "quem consulta lista e vê; só quem registra vê os botões de escrita" do
    { operador: true, admin: true, consultor: false }.each do |papel, escreve|
      sign_in users(papel)

      get formulario_avaliacoes_clinicas_path(FORMULARIO)
      assert_response :success
      assert_includes response.body, "MFU"
      assert_equal escreve, response.body.include?(new_formulario_avaliacao_clinica_path(FORMULARIO)), "#{papel}: botão de nova"
      assert_equal escreve, response.body.include?(edit_formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:one))), "#{papel}: link de editar"

      get formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:two))
      assert_response :success
      assert_includes response.body, "Pleural; Ganglionar"
    end
  end

  test "busca pelo prontuário SAH ou AGHUSE" do
    sign_in users(:consultor)

    get formulario_avaliacoes_clinicas_path(FORMULARIO, prontuario: "AGH-0002")
    assert_includes response.body, "JPD"
    assert_not_includes response.body, "MFU"
  end

  test "operador e admin abrem o formulário com a pergunta 10 condicional; consultor não abre" do
    %i[operador admin].each do |papel|
      sign_in users(papel)
      get new_formulario_avaliacao_clinica_path(FORMULARIO)

      assert_response :success, papel
      assert_select "input[name='avaliacao_clinica[dados_formulario][forma_clinica]'][data-revela]", 2
      assert_select ".pergunta-condicional input[type=checkbox][name='avaliacao_clinica[dados_formulario][tb_extrapulmonar][]']", 10
    end

    sign_in users(:consultor)
    get new_formulario_avaliacao_clinica_path(FORMULARIO)
    assert_redirected_to root_path
  end

  # --- Liberações por setor ---------------------------------------------------

  test "a lista traz só as notificações dos setores liberados" do
    sign_in users(:operador)
    get formulario_avaliacoes_clinicas_path(FORMULARIO)
    assert_includes response.body, "MFU"
    assert_not_includes response.body, "LBX"

    sign_in users(:laboratorista)
    get formulario_avaliacoes_clinicas_path(FORMULARIO)
    assert_includes response.body, "LBX"
    assert_not_includes response.body, "MFU"
  end

  test "notificação de outro setor dá 404 pela URL: ver, editar e salvar" do
    do_laboratorio = avaliacoes_clinicas(:tres)
    # No teste, o login do sign_in vale para a próxima requisição; uma que
    # termina em 404 não grava a sessão, então entra-se de novo antes de cada uma
    sign_in users(:operador)
    get formulario_avaliacao_clinica_path(FORMULARIO, do_laboratorio)
    assert_response :not_found
    sign_in users(:operador)
    get edit_formulario_avaliacao_clinica_path(FORMULARIO, do_laboratorio)
    assert_response :not_found
    sign_in users(:operador)
    atualizar do_laboratorio, do_laboratorio.respostas.merge("baciloscopia_escarro_mes_1" => "1")
    assert_response :not_found
    assert_nil do_laboratorio.reload.respostas["baciloscopia_escarro_mes_1"]
  end

  test "não registra em setor sem liberação, mesmo trocando o setor no formulário" do
    sign_in users(:operador)

    assert_no_difference [ "Paciente.count", "AvaliacaoClinica.count" ] do
      enviar paciente: { prontuario_sah: "SAH-NOVO", iniciais: "ABC" }, setor: setores(:laboratorio)
      enviar paciente: { prontuario_sah: "SAH-NOVO", iniciais: "ABC" }, setor: nil
      enviar paciente: { prontuario_sah: "SAH-NOVO", iniciais: "ABC" }, setor: 0
    end
    assert_redirected_to root_path
  end

  test "sem liberação no formulário, a lista nem abre" do
    sign_in users(:sem_acesso)

    get formulario_avaliacoes_clinicas_path(FORMULARIO)
    assert_redirected_to root_path
    get new_formulario_avaliacao_clinica_path(FORMULARIO)
    assert_redirected_to root_path
  end

  test "a busca por prontuário não cruza setores" do
    sign_in users(:operador)
    get formulario_avaliacoes_clinicas_path(FORMULARIO, prontuario: "SAH-0001")

    assert_includes response.body, "MFU"
    assert_not_includes response.body, "LBX"
  end

  test "a tela de nova oferece só os setores em que a pessoa registra" do
    sign_in users(:operador)
    get new_formulario_avaliacao_clinica_path(FORMULARIO)
    assert_select "input[type=hidden][name='avaliacao_clinica[setor_id]'][value='#{setores(:ambulatorio).id}']"
    assert_select "select[name='avaliacao_clinica[setor_id]']", 0

    sign_in users(:admin)
    get new_formulario_avaliacao_clinica_path(FORMULARIO)
    assert_select "select[name='avaliacao_clinica[setor_id]'] option:not([value=''])", 2
  end

  test "o mesmo prontuário em outro setor é outro paciente" do
    sign_in users(:laboratorista)

    assert_difference [ "Paciente.count", "AvaliacaoClinica.count" ], 1 do
      enviar paciente: { prontuario_sah: "SAH-0002", iniciais: "NOV" }, setor: setores(:laboratorio)
    end
    novo = AvaliacaoClinica.last
    assert_equal setores(:laboratorio), novo.setor
    assert_equal setores(:laboratorio), novo.paciente.setor
    assert_not_equal pacientes(:two), novo.paciente
  end

  test "o filtro de setor só vale para setores visíveis" do
    sign_in users(:admin)
    get formulario_avaliacoes_clinicas_path(FORMULARIO, setor: setores(:laboratorio).id)
    assert_includes response.body, "LBX"
    assert_not_includes response.body, "MFU"

    # Para quem não vê o Laboratório, o filtro é ignorado e não revela nada de lá
    sign_in users(:operador)
    get formulario_avaliacoes_clinicas_path(FORMULARIO, setor: setores(:laboratorio).id)
    assert_includes response.body, "MFU"
    assert_not_includes response.body, "LBX"
  end

  test "registra paciente novo e notificação, com autor e auditoria sem texto puro" do
    sign_in users(:operador)

    assert_difference [ "Paciente.count", "AvaliacaoClinica.count" ], 1 do
      enviar paciente: { prontuario_sah: "SAH-NOVO", iniciais: "a.b.c.d.e.f.g.h" },
             respostas: respostas_de_abertura("municipio_residencia" => "Município Secreto")
    end

    avaliacao = AvaliacaoClinica.last
    assert_redirected_to formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)
    assert_equal "ABCDEFGH", avaliacao.paciente.iniciais
    assert_equal users(:operador).id.to_s, avaliacao.versions.last.whodunnit
    assert_not_includes avaliacao.versions.last.object_changes, "Município Secreto"
    assert_not_includes avaliacao.paciente.versions.last.object_changes, "ABCDEFGH"
  end

  # Regressão: o fluxo antigo sobrescrevia o cadastro de quem tivesse o identificador enviado
  test "paciente existente é só vinculado e a identificação não muda" do
    sign_in users(:operador)
    paciente = pacientes(:one)

    assert_no_difference "Paciente.count" do
      assert_difference "paciente.avaliacoes_clinicas.count", 1 do
        enviar paciente: { prontuario_sah: "SAH-0001", prontuario_aghuse: "", iniciais: "MFU" }
      end
    end
    assert_equal "AGH-0001", paciente.reload.prontuario_aghuse
    assert_match "não foi alterada", flash[:notice]
  end

  test "iniciais que não conferem com o prontuário são recusadas sem gravar" do
    sign_in users(:operador)

    assert_no_difference [ "Paciente.count", "AvaliacaoClinica.count" ] do
      enviar paciente: { prontuario_sah: "SAH-0001", iniciais: "XYZ" }
    end
    assert_response :unprocessable_content
    assert_includes response.body, "As iniciais não conferem"
  end

  test "respostas inválidas não gravam nada e aparecem ao lado da pergunta" do
    sign_in users(:operador)

    assert_no_difference [ "Paciente.count", "AvaliacaoClinica.count" ] do
      enviar paciente: { prontuario_sah: "SAH-NOVO", iniciais: "" }, respostas: respostas_de_abertura("forma_clinica" => "2")
    end
    assert_response :unprocessable_content
    assert_select ".pergunta-condicional p.text-rose-600", text: "é obrigatória"
    assert_select "#campo_iniciais[aria-invalid='true']"
  end

  test "consultor não registra" do
    sign_in users(:consultor)

    assert_no_difference [ "Paciente.count", "AvaliacaoClinica.count" ] do
      enviar paciente: { prontuario_sah: "SAH-NOVO", iniciais: "ABC" }
    end
    assert_redirected_to root_path
  end

  test "operador atualiza o seguimento mês a mês, e a alteração fica auditada" do
    sign_in users(:operador)
    avaliacao = avaliacoes_clinicas(:one)

    get edit_formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)
    assert_response :success
    assert_select "input[name='paciente[iniciais]']", 0 # identificação só para leitura

    assert_difference -> { avaliacao.versions.count }, 1 do
      atualizar avaliacao, avaliacao.respostas.merge("baciloscopia_escarro_mes_1" => "2")
    end
    assert_redirected_to formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)
    assert_equal "2", avaliacao.reload.respostas["baciloscopia_escarro_mes_1"]
  end

  test "encerrar exige as perguntas marcadas para encerrar" do
    sign_in users(:admin)
    avaliacao = avaliacoes_clinicas(:one)

    atualizar avaliacao, avaliacao.respostas.merge("data_encerramento" => Date.current.iso8601)
    assert_response :unprocessable_content
    assert_includes response.body, "é obrigatória para encerrar a notificação"

    atualizar avaliacao, avaliacao.respostas.merge(respostas_de_encerramento)
    assert avaliacao.reload.encerrada?
  end

  test "consultor não edita" do
    sign_in users(:consultor)
    avaliacao = avaliacoes_clinicas(:one)

    get edit_formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)
    assert_redirected_to root_path

    atualizar avaliacao, avaliacao.respostas.merge("baciloscopia_escarro_mes_1" => "1")
    assert_redirected_to root_path
    assert_nil avaliacao.reload.respostas["baciloscopia_escarro_mes_1"]
  end

  test "edição sobre uma versão antiga avisa do conflito em vez de sobrescrever" do
    sign_in users(:operador)
    avaliacao = avaliacoes_clinicas(:one)
    versao_aberta = avaliacao.lock_version
    avaliacao.update!(dados_formulario: avaliacao.respostas.merge("numero_contatos" => 2))

    atualizar avaliacao, avaliacao.respostas.merge("numero_contatos" => 9), lock_version: versao_aberta
    assert_response :conflict
    assert_equal 2, avaliacao.reload.respostas["numero_contatos"]
  end

  test "dados do paciente e respostas não vão para o log" do
    sign_in users(:operador)
    enviar paciente: { prontuario_sah: "SAH-NOVO", iniciais: "ABC" }

    assert_equal "[FILTERED]", request.filtered_parameters["paciente"]
    assert_equal "[FILTERED]", request.filtered_parameters["avaliacao_clinica"]
  end

  private

  def enviar(paciente:, respostas: respostas_de_abertura, setor: setores(:ambulatorio))
    post formulario_avaliacoes_clinicas_path(FORMULARIO), params: {
      paciente: { prontuario_sah: "", prontuario_aghuse: "", iniciais: "" }.merge(paciente),
      avaliacao_clinica: { setor_id: setor.respond_to?(:id) ? setor.id : setor, dados_formulario: respostas }
    }
  end

  def atualizar(avaliacao, respostas, lock_version: avaliacao.reload.lock_version)
    patch formulario_avaliacao_clinica_path(FORMULARIO, avaliacao), params: {
      avaliacao_clinica: { lock_version:, dados_formulario: respostas }
    }
  end
end
