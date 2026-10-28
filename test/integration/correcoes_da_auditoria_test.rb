require "test_helper"
require "rake"

# Trava as correções da auditoria de segurança e LGPD: cada teste falha se a
# correção correspondente for desfeita.
class CorrecoesDaAuditoriaTest < ActionDispatch::IntegrationTest
  FORMULARIO = "acompanhamento".freeze

  test "o termo da busca e o login não vão em texto claro para o log" do
    filtro = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtrado = filtro.filter("termo" => "SAH-0001", "usuario" => { "username" => "maria.s", "nome" => "Maria" })
    assert_equal "[FILTERED]", filtrado["termo"]
    assert_equal "[FILTERED]", filtrado["usuario"]["username"]

    requisicao = ActionDispatch::TestRequest.create("QUERY_STRING" => "termo=MFU", "PATH_INFO" => "/buscar", "REQUEST_METHOD" => "GET")
    assert_not_includes requisicao.filtered_path, "MFU"
  end

  test "quem não é admin recebe a mesma resposta para um id que existe e para um que não existe" do
    sign_in users(:operador)

    [ edit_configuracoes_usuario_path(users(:consultor)), edit_configuracoes_usuario_path(0),
      edit_configuracoes_usuario_liberacoes_path(users(:consultor)), edit_configuracoes_usuario_liberacoes_path(0),
      edit_configuracoes_usuario_senha_path(users(:consultor)), edit_configuracoes_usuario_senha_path(0),
      edit_configuracoes_instituicao_path(instituicoes(:centro)), edit_configuracoes_instituicao_path(0),
      new_configuracoes_instituicao_setor_path(instituicoes(:centro)), new_configuracoes_instituicao_setor_path(0) ].each do |caminho|
      get caminho
      assert_response :see_other, caminho
    end
  end

  test "as sugestões de busca vêm só dos pacientes da página, que está na auditoria de leitura" do
    sign_in users(:consultor)

    assert_difference -> { AuditLog.count }, 2 do
      get formulario_avaliacoes_clinicas_path(FORMULARIO, filtros: 1)
    end
    sugeridos = css_select("datalist#sugestoes_de_busca option").map { |opcao| opcao["value"] }
    exibidos = AuditLog.order(:id).last(2).map { |leitura| leitura.auditable.paciente }
    assert_equal Paciente.sugestoes_de_busca(exibidos), sugeridos
  end

  test "a resposta proíbe câmera, microfone e localização" do
    sign_in users(:operador)
    get root_path

    politica = response.headers["Permissions-Policy"]
    assert_match(/camera=\(\)/, politica)
    assert_match(/microphone=\(\)/, politica)
    assert_match(/geolocation=\(\)/, politica)
  end

  test "a troca de senha recusa senha previsível" do
    usuario = users(:operador)
    previsiveis = [ "12345678", "aaaaaaaaaa", "Password", "xx#{usuario.username}xx", "A#{usuario.cpf}z" ]

    previsiveis.each do |senha|
      usuario.password = senha
      assert_not usuario.valid?, "#{senha} devia ser recusada"
      assert usuario.errors[:password].any? { |erro| erro.include?("previsível") }, senha
    end

    usuario.password = "cavalo-bateria-grampo-7"
    assert usuario.valid?, usuario.errors.full_messages.to_sentence
  end

  test "o descarte da auditoria exige o prazo, só conta sem confirmação e apaga com ela" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("prisma:descartar_leituras")
    tarefa = Rake::Task["prisma:descartar_leituras"]
    velha = AuditLog.insert_all!([ { user_id: users(:admin).id, auditable_type: "AvaliacaoClinica", auditable_id: avaliacoes_clinicas(:one).id,
                                     action: "show", created_at: 400.days.ago } ])
    recente = AuditLog.insert_all!([ { user_id: users(:admin).id, auditable_type: "AvaliacaoClinica", auditable_id: avaliacoes_clinicas(:one).id,
                                       action: "show", created_at: 1.day.ago } ])
    assert velha && recente

    com_ambiente("DIAS" => nil) { assert_raises(SystemExit) { capture_io { tarefa.execute } } }
    com_ambiente("DIAS" => "abc") { assert_raises(SystemExit) { capture_io { tarefa.execute } } }

    com_ambiente("DIAS" => "365", "CONFIRMAR" => nil) do
      assert_no_difference -> { AuditLog.count } do
        saida, = capture_io { tarefa.execute }
        assert_match(/1 leituras anteriores/, saida)
      end
    end

    com_ambiente("DIAS" => "365", "CONFIRMAR" => "sim") do
      assert_difference -> { AuditLog.count }, -1 do
        capture_io { tarefa.execute }
      end
    end
    assert_operator AuditLog.where("created_at > ?", 2.days.ago).count, :>=, 1
  end

  private

  def com_ambiente(variaveis)
    antigas = variaveis.keys.index_with { |chave| ENV[chave] }
    variaveis.each { |chave, valor| ENV[chave] = valor }
    yield
  ensure
    antigas.each { |chave, valor| ENV[chave] = valor }
  end
end
