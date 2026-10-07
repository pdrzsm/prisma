require "test_helper"

# Correção da identificação do paciente (LGPD, art. 18, III): só prontuários e
# iniciais, por quem registra as notificações dele, com o autor no PaperTrail
class CorrecaoDeIdentificacaoTest < ActionDispatch::IntegrationTest
  FORMULARIO = "seguimento_tb".freeze

  test "o botão aparece nos detalhes da notificação só para quem pode corrigir" do
    avaliacao = avaliacoes_clinicas(:one)

    sign_in users(:operador)
    get formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)
    assert_select "a[href=?]", edit_paciente_identificacao_path(pacientes(:one), avaliacao:), text: "Corrigir identificação"

    sign_in users(:consultor)
    get formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)
    assert_response :success
    assert_select "a", text: "Corrigir identificação", count: 0
  end

  test "a correção altera os dados, volta para a notificação e fica no PaperTrail com o autor" do
    sign_in users(:operador)
    paciente = pacientes(:one)
    avaliacao = avaliacoes_clinicas(:one)

    get edit_paciente_identificacao_path(paciente, avaliacao:)
    assert_response :success
    assert_select "input[name='paciente[prontuario_sah]'][value='SAH-0001']"
    assert_select "input[name='paciente[iniciais]'][value='MFU']"

    assert_difference -> { paciente.versions.count }, 1 do
      corrigir paciente, { prontuario_sah: "sah 0099", prontuario_aghuse: "", iniciais: "m. f. v." }, avaliacao:
    end
    assert_redirected_to formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)

    paciente.reload
    assert_equal [ "SAH0099", nil, "MFV" ], [ paciente.prontuario_sah, paciente.prontuario_aghuse, paciente.iniciais ]
    versao = paciente.versions.last
    assert_equal "update", versao.event
    assert_equal users(:operador).id.to_s, versao.whodunnit

    # A notificação mostra a identificação nova e a correção no histórico
    follow_redirect!
    assert_select "h1", text: /MFV/
    assert_select "li", text: /Identificação do paciente corrigida\s+por\s+@operador_teste/
  end

  test "só prontuários e iniciais: o setor e o resto do cadastro não mudam" do
    sign_in users(:admin)
    paciente = pacientes(:one)

    corrigir paciente, { iniciais: "MFU", setor_id: setores(:laboratorio).id, created_at: 1.year.ago }

    assert_redirected_to formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:one))
    assert_equal setores(:ambulatorio), paciente.reload.setor
    assert_not_equal 1.year.ago.to_date, paciente.created_at.to_date
  end

  test "sem nada diferente, nada é gravado" do
    sign_in users(:operador)

    assert_no_difference -> { PaperTrail::Version.count } do
      corrigir pacientes(:one), { prontuario_sah: "sah-0001", prontuario_aghuse: "agh-0001", iniciais: "mfu" }
    end
    follow_redirect!
    assert_includes response.body, "Nada foi alterado na identificação."
  end

  test "prontuário de outro paciente do setor é recusado; de outro setor, não" do
    sign_in users(:operador)

    corrigir pacientes(:one), { prontuario_sah: "SAH-0002" } # é do paciente two, no mesmo setor
    assert_response :unprocessable_content
    assert_select "#paciente_prontuario_sah[aria-invalid=true]"
    assert_includes response.body, "já é de outro paciente deste setor"
    assert_equal "SAH-0001", pacientes(:one).reload.prontuario_sah

    # AGH-0001 é do paciente one, no Ambulatório; no Laboratório é outro cadastro
    sign_in users(:laboratorista)
    corrigir pacientes(:tres), { prontuario_aghuse: "AGH-0001" }
    assert_redirected_to formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:tres))
    assert_equal "AGH-0001", pacientes(:tres).reload.prontuario_aghuse
  end

  test "iniciais em branco não salvam, e a tela volta com o erro" do
    sign_in users(:operador)

    assert_no_difference -> { PaperTrail::Version.count } do
      corrigir pacientes(:one), { iniciais: " . " }
    end
    assert_response :unprocessable_content
    assert_select "#paciente_iniciais[aria-invalid=true]"
    assert_select "h1", text: /MFU/, message: "o título continua com as iniciais do cadastro"
    assert_equal "MFU", pacientes(:one).reload.iniciais
  end

  test "prontuário gravado por outra pessoa no mesmo instante: avisa em vez de quebrar" do
    sign_in users(:operador)
    Paciente.define_method(:save) { |*| raise ActiveRecord::RecordNotUnique, "Duplicate entry" }

    corrigir pacientes(:one), { prontuario_sah: "SAH-0099" }
    assert_response :unprocessable_content
    assert_includes response.body, "acabou de ser cadastrado para outro paciente do setor"
  ensure
    Paciente.send(:remove_method, :save)
  end

  test "quem só consulta não corrige, e de outro setor nem encontra o paciente" do
    sign_in users(:consultor)
    assert_no_difference -> { AuditLog.count } do
      get edit_paciente_identificacao_path(pacientes(:one))
    end
    assert_redirected_to root_path
    corrigir pacientes(:one), { iniciais: "XYZ" }
    assert_redirected_to root_path
    assert_equal "MFU", pacientes(:one).reload.iniciais

    sign_in users(:operador)
    get edit_paciente_identificacao_path(pacientes(:tres))
    assert_response :not_found
    corrigir pacientes(:tres), { iniciais: "XYZ" }
    assert_response :not_found
    assert_equal "LBX", pacientes(:tres).reload.iniciais

    sign_in users(:sem_acesso)
    get edit_paciente_identificacao_path(pacientes(:one))
    assert_response :not_found
  end

  test "a volta é sempre para uma notificação do paciente que a pessoa vê" do
    sign_in users(:admin)

    # Notificação de outro paciente na URL é ignorada
    corrigir pacientes(:one), { iniciais: "MFX" }, avaliacao: avaliacoes_clinicas(:tres)
    assert_redirected_to formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:one))
  end

  test "a tela mostra a identificação: fica na auditoria de leitura" do
    sign_in users(:operador)
    paciente = pacientes(:one)

    assert_difference -> { AuditLog.count }, 1 do
      get edit_paciente_identificacao_path(paciente)
    end
    assert_equal [ paciente, "edit" ], [ AuditLog.last.auditable, AuditLog.last.action ]

    # A correção que volta com erro também mostra
    assert_difference -> { AuditLog.count }, 1 do
      corrigir paciente, { iniciais: "" }
    end
    assert_equal [ paciente, "update" ], [ AuditLog.last.auditable, AuditLog.last.action ]
    assert_includes AuditLog.do_paciente(paciente), AuditLog.last

    # A que salva não: os dados aparecem depois, na notificação
    assert_no_difference -> { AuditLog.count } do
      corrigir paciente, { iniciais: "MFX" }
    end
  end

  test "prontuários e iniciais não vão para o log" do
    sign_in users(:operador)
    corrigir pacientes(:one), { iniciais: "ABC" }

    assert_equal "[FILTERED]", request.filtered_parameters["paciente"]
  end

  private

  def corrigir(paciente, campos, avaliacao: nil)
    patch paciente_identificacao_path(paciente), params: { paciente: campos, avaliacao: avaliacao&.id }.compact
  end
end
