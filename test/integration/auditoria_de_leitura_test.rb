require "test_helper"

# Auditoria de leitura (LGPD, art. 37 e 46): toda tela que mostra dado sensível
# grava quem viu, quando, qual registro e de qual IP
class AuditoriaDeLeituraTest < ActionDispatch::IntegrationTest
  FORMULARIO = "seguimento_tb".freeze
  NAVEGADOR = { "User-Agent" => "Navegador de Teste/1.0" }.freeze

  test "ver os detalhes grava uma linha com quem, quando, qual registro e de qual IP" do
    sign_in users(:operador)
    avaliacao = avaliacoes_clinicas(:one)

    assert_difference -> { AuditLog.count }, 1 do
      get formulario_avaliacao_clinica_path(FORMULARIO, avaliacao), headers: NAVEGADOR
    end
    assert_response :success
    log = AuditLog.last
    assert_equal users(:operador), log.user
    assert_equal avaliacao, log.auditable
    assert_equal "show", log.action
    assert_equal "127.0.0.1", log.ip_address
    assert_equal "Navegador de Teste/1.0", log.user_agent
    assert_in_delta Time.current, log.created_at, 5.seconds
  end

  test "a lista grava uma linha por notificação exibida, e só das exibidas" do
    sign_in users(:operador)

    assert_difference -> { AuditLog.count }, 2 do
      get formulario_avaliacoes_clinicas_path(FORMULARIO)
    end
    vistas = AuditLog.where(action: "index").map(&:auditable)
    assert_equal avaliacoes_clinicas(:one, :two).sort, vistas.sort
    assert_not_includes vistas, avaliacoes_clinicas(:tres), "a do Laboratório não aparece para o operador"
  end

  test "a busca grava só os resultados; sem resultado, nada" do
    sign_in users(:operador)

    assert_difference -> { AuditLog.count }, 1 do
      get formulario_avaliacoes_clinicas_path(FORMULARIO, prontuario: "AGH-0002")
    end
    assert_equal avaliacoes_clinicas(:two), AuditLog.last.auditable

    assert_no_difference -> { AuditLog.count } do
      get formulario_avaliacoes_clinicas_path(FORMULARIO, prontuario: "NAO-EXISTE")
    end
  end

  test "a tela de edição também é leitura" do
    sign_in users(:operador)

    assert_difference -> { AuditLog.count }, 1 do
      get edit_formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:one))
    end
    assert_equal "edit", AuditLog.last.action
  end

  test "a edição que volta sem salvar também é leitura" do
    sign_in users(:operador)
    avaliacao = avaliacoes_clinicas(:one)

    # Resposta inválida: a tela de edição volta com os dados
    assert_difference -> { AuditLog.count }, 1 do
      atualizar avaliacao, avaliacao.respostas.merge("data_encerramento" => Date.current.iso8601)
    end
    assert_response :unprocessable_content
    assert_equal [ avaliacao, "update" ], [ AuditLog.last.auditable, AuditLog.last.action ]

    # Conflito com a alteração de outra pessoa: também volta com os dados
    assert_difference -> { AuditLog.count }, 1 do
      atualizar avaliacao, avaliacao.respostas, lock_version: avaliacao.lock_version - 1
    end
    assert_response :conflict
    assert_equal "update", AuditLog.last.action
  end

  test "a edição salva não é leitura: os dados aparecem depois, nos detalhes" do
    sign_in users(:operador)
    avaliacao = avaliacoes_clinicas(:one)

    assert_no_difference -> { AuditLog.count } do
      atualizar avaliacao, avaliacao.respostas.merge("numero_contatos" => 3)
    end
    assert_redirected_to formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)
  end

  test "o admin também fica registrado" do
    sign_in users(:admin)
    get formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:tres))

    assert_equal users(:admin), AuditLog.last.user
  end

  test "acesso negado não vira leitura" do
    sign_in users(:operador)
    assert_no_difference -> { AuditLog.count } do
      get formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:tres)) # outro setor: 404
    end

    sign_in users(:consultor)
    assert_no_difference -> { AuditLog.count } do
      get edit_formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:one)) # consulta não edita
    end

    sign_in users(:sem_acesso)
    assert_no_difference -> { AuditLog.count } do
      get formulario_avaliacoes_clinicas_path(FORMULARIO)
    end
  end

  test "o navegador é guardado com no máximo 255 caracteres" do
    sign_in users(:operador)
    get formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:one)), headers: { "User-Agent" => "x" * 1000 }

    assert_equal 255, AuditLog.last.user_agent.length
  end

  test "sem conseguir gravar a auditoria, os dados não são mostrados" do
    sign_in users(:operador)
    AuditLog.define_singleton_method(:insert_all!) { |*| raise ActiveRecord::StatementInvalid, "banco fora" }

    assert_raises(ActiveRecord::StatementInvalid) do
      get formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:one))
    end
  ensure
    AuditLog.singleton_class.send(:remove_method, :insert_all!)
  end

  private

  def atualizar(avaliacao, respostas, lock_version: avaliacao.reload.lock_version)
    patch formulario_avaliacao_clinica_path(FORMULARIO, avaliacao), params: {
      avaliacao_clinica: { lock_version:, dados_formulario: respostas }
    }
  end
end
