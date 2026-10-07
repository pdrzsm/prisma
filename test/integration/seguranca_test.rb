require "test_helper"

class SegurancaTest < ActionDispatch::IntegrationTest
  FORMULARIO = "seguimento_tb".freeze
  CABECALHOS = {
    "Cache-Control" => "no-store",
    "X-Frame-Options" => "SAMEORIGIN",
    "X-Content-Type-Options" => "nosniff",
    "Content-Security-Policy" => "default-src 'self'"
  }.freeze

  test "toda rota do sistema exige login, menos o health check" do
    avaliacao = avaliacoes_clinicas(:one)
    paginas = [
      root_path, formularios_path,
      formulario_avaliacoes_clinicas_path(FORMULARIO), new_formulario_avaliacao_clinica_path(FORMULARIO),
      formulario_avaliacao_clinica_path(FORMULARIO, avaliacao), edit_formulario_avaliacao_clinica_path(FORMULARIO, avaliacao),
      edit_paciente_identificacao_path(avaliacao.paciente), privacidade_path
    ]
    paginas.each do |pagina|
      get pagina
      assert_redirected_to new_user_session_path, pagina
    end

    post formulario_avaliacoes_clinicas_path(FORMULARIO)
    assert_redirected_to new_user_session_path
    patch formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)
    assert_redirected_to new_user_session_path
    patch paciente_identificacao_path(avaliacao.paciente)
    assert_redirected_to new_user_session_path

    get rails_health_check_path
    assert_response :success
  end

  test "todas as telas saem com os cabeçalhos de proteção" do
    get new_user_session_path
    assert_cabecalhos "login"

    sign_in users(:operador)
    avaliacao = avaliacoes_clinicas(:one)
    [ root_path, formularios_path, formulario_avaliacoes_clinicas_path(FORMULARIO),
      new_formulario_avaliacao_clinica_path(FORMULARIO), formulario_avaliacao_clinica_path(FORMULARIO, avaliacao),
      edit_formulario_avaliacao_clinica_path(FORMULARIO, avaliacao), edit_paciente_identificacao_path(avaliacao.paciente),
      privacidade_path ].each do |pagina|
      get pagina
      assert_response :success
      assert_cabecalhos pagina
    end
  end

  test "texto digitado nunca vira HTML (XSS)" do
    sign_in users(:operador)
    ataque = %(<script>alert("x")</script><img src=x onerror=alert(1)>)

    post formulario_avaliacoes_clinicas_path(FORMULARIO), params: {
      paciente: { prontuario_sah: "<b>SAH</b>", prontuario_aghuse: "", iniciais: "ABC" },
      avaliacao_clinica: { setor_id: setores(:ambulatorio).id, dados_formulario: respostas_de_abertura("municipio_residencia" => ataque[0, 100], "numero_sinan" => "<i>1</i>",
                                                                   "motivo_mudanca_esquema" => ataque) }
    }
    avaliacao = AvaliacaoClinica.last
    assert_redirected_to formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)

    [ formulario_avaliacao_clinica_path(FORMULARIO, avaliacao), edit_formulario_avaliacao_clinica_path(FORMULARIO, avaliacao),
      edit_paciente_identificacao_path(avaliacao.paciente), formulario_avaliacoes_clinicas_path(FORMULARIO) ].each do |pagina|
      get pagina
      [ %r{<script>alert}i, %r{<img src=x}i, %r{<b>SAH</b>}i, %r{<i>1</i>}i ].each do |trecho|
        assert_no_match trecho, response.body, pagina
      end
    end
    # Na lista, o número SINAN aparece escapado
    assert_includes response.body, "&lt;i&gt;1&lt;/i&gt;"
  end

  test "campos que não pertencem ao formulário são ignorados (atribuição em massa)" do
    sign_in users(:operador)
    outro_paciente = pacientes(:two)

    post formulario_avaliacoes_clinicas_path(FORMULARIO), params: {
      paciente: { prontuario_sah: "SAH-NOVO", prontuario_aghuse: "", iniciais: "ABC", id: outro_paciente.id },
      avaliacao_clinica: { setor_id: setores(:ambulatorio).id, user_id: users(:admin).id, paciente_id: outro_paciente.id, formulario: "outro", lock_version: 99,
                           created_at: 1.year.ago, dados_formulario: respostas_de_abertura }
    }
    avaliacao = AvaliacaoClinica.last
    assert_equal users(:operador), avaliacao.user
    assert_equal "seguimento_tb", avaliacao.formulario
    assert_not_equal outro_paciente, avaliacao.paciente
    assert_equal 0, avaliacao.lock_version
    assert avaliacao.created_at > 1.minute.ago

    patch formulario_avaliacao_clinica_path(FORMULARIO, avaliacao), params: {
      avaliacao_clinica: { lock_version: 0, user_id: users(:admin).id, paciente_id: outro_paciente.id, formulario: "outro",
                           dados_formulario: respostas_de_abertura }
    }
    avaliacao.reload
    assert_equal users(:operador), avaliacao.user
    assert_not_equal outro_paciente, avaliacao.paciente
    assert_equal "seguimento_tb", avaliacao.formulario
  end

  test "estrutura fora do formulário é descartada antes de chegar ao model" do
    sign_in users(:operador)

    assert_no_difference "AvaliacaoClinica.count" do
      post formulario_avaliacoes_clinicas_path(FORMULARIO), params: {
        paciente: { prontuario_sah: "SAH-NOVO", prontuario_aghuse: "", iniciais: "ABC" },
        avaliacao_clinica: { setor_id: setores(:ambulatorio).id, dados_formulario: respostas_de_abertura("gestante" => { "x" => "1" }, "campo_inventado" => "1") }
      }
    end
    assert_response :unprocessable_content
    assert_select "#campo_gestante_1" # a pergunta volta para ser respondida
    assert_includes response.body, "é obrigatória"
  end

  test "registro de outro formulário não abre pela URL deste" do
    sign_in users(:admin)
    avaliacao = avaliacoes_clinicas(:one)
    avaliacao.update_column(:formulario, "outro_formulario")

    get formulario_avaliacao_clinica_path(FORMULARIO, avaliacao)
    assert_response :not_found
  end

  test "sem permissão, volta para uma página do próprio sistema, nunca para outro site" do
    sign_in users(:consultor)

    get edit_formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:one)), headers: { "Referer" => "https://malicioso.example/roubo" }
    assert_redirected_to root_path
  end

  test "envio sem o token CSRF é recusado" do
    ActionController::Base.allow_forgery_protection = true
    sign_in users(:operador)

    assert_no_difference "AvaliacaoClinica.count" do
      post formulario_avaliacoes_clinicas_path(FORMULARIO), params: {
        paciente: { prontuario_sah: "SAH-NOVO", prontuario_aghuse: "", iniciais: "ABC" },
        avaliacao_clinica: { setor_id: setores(:ambulatorio).id, dados_formulario: respostas_de_abertura }
      }
    end
    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "não existe versão JSON dos registros" do
    sign_in users(:operador)

    get formulario_avaliacao_clinica_path(FORMULARIO, avaliacoes_clinicas(:one), format: :json)
    assert_response :not_acceptable
    assert_not_equal "application/json", response.media_type
  end

  test "busca e paginação aceitam qualquer entrada sem erro" do
    sign_in users(:consultor)

    [ "' OR '1'='1", "%", "SAH-0001' --" ].each do |prontuario|
      get formulario_avaliacoes_clinicas_path(FORMULARIO, prontuario:)
      assert_response :success, prontuario
      assert_includes response.body, "Nenhum registro com esse filtro", prontuario
    end

    [ "-3", "abc" ].each do |pagina|
      get formulario_avaliacoes_clinicas_path(FORMULARIO, pagina:)
      assert_response :success, pagina
      assert_includes response.body, "MFU", "página #{pagina} vira a primeira"
    end

    get formulario_avaliacoes_clinicas_path(FORMULARIO, pagina: "999999")
    assert_includes response.body, "Não há registros nesta página"
  end

  test "o prontuário buscado não aparece no log" do
    sign_in users(:consultor)
    get formulario_avaliacoes_clinicas_path(FORMULARIO, prontuario: "SAH-0001")

    assert_includes request.filtered_path, "prontuario=[FILTERED]"
  end

  private

  def assert_cabecalhos(pagina)
    CABECALHOS.each do |nome, valor|
      assert_includes response.headers[nome].to_s, valor, "#{nome} em #{pagina}"
    end
  end
end
