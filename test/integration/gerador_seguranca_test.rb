require "test_helper"

# Segurança do gerador de formulários: só o admin entra (sem nem descobrir
# quais formulários existem), nenhum texto digitado no gerador vira HTML em
# tela nenhuma, nada fora do que a tela pede é aceito, e formulário não
# publicado não é preenchido por ninguém.
class GeradorSegurancaTest < ActionDispatch::IntegrationTest
  ATAQUE = %(<script>alert("x")</script><img src=x onerror=alert(1)>).freeze

  # Todas as rotas do gerador, com um formulário publicado (o das fixtures) e um
  # rascunho; e chaves que não existem, para ver que o 404 não vaza para quem
  # não é admin
  def rotas_do_gerador(chave = "acompanhamento", pergunta = "gestante")
    [
      [ :get, configuracoes_formularios_path ], [ :get, new_configuracoes_formulario_path ],
      [ :post, configuracoes_formularios_path, { formulario: { titulo: "Invasor" } } ],
      [ :get, configuracoes_formulario_path(chave) ], [ :get, excluir_configuracoes_formulario_path(chave) ],
      [ :delete, configuracoes_formulario_path(chave) ],
      [ :get, configuracoes_formulario_rascunho_path(chave) ], [ :post, configuracoes_formulario_rascunho_path(chave) ],
      [ :patch, configuracoes_formulario_rascunho_path(chave), { lock_version: 0, cabecalho: { titulo: "Invasor" } } ],
      [ :delete, configuracoes_formulario_rascunho_path(chave) ], [ :get, descartar_configuracoes_formulario_rascunho_path(chave) ],
      [ :get, previa_configuracoes_formulario_rascunho_path(chave) ],
      [ :get, new_configuracoes_formulario_rascunho_secao_path(chave) ],
      [ :post, configuracoes_formulario_rascunho_secoes_path(chave), { lock_version: 0, secao: { titulo: "Invasor" } } ],
      [ :get, edit_configuracoes_formulario_rascunho_secao_path(chave, "s1") ],
      [ :patch, configuracoes_formulario_rascunho_secao_path(chave, "s1"), { lock_version: 0, secao: { titulo: "Invasor" } } ],
      [ :delete, configuracoes_formulario_rascunho_secao_path(chave, "s1"), { lock_version: 0 } ],
      [ :patch, mover_configuracoes_formulario_rascunho_secao_path(chave, "s1"), { lock_version: 0, direcao: "abaixo" } ],
      [ :get, new_configuracoes_formulario_rascunho_pergunta_path(chave, secao: "s1") ],
      [ :post, configuracoes_formulario_rascunho_perguntas_path(chave), { lock_version: 0, secao: "s1", pergunta: { texto: "Invasor", tipo: "texto" } } ],
      [ :get, edit_configuracoes_formulario_rascunho_pergunta_path(chave, pergunta) ],
      [ :patch, configuracoes_formulario_rascunho_pergunta_path(chave, pergunta), { lock_version: 0, pergunta: { texto: "Invasor", tipo: "texto" } } ],
      [ :get, remover_configuracoes_formulario_rascunho_pergunta_path(chave, pergunta) ],
      [ :delete, configuracoes_formulario_rascunho_pergunta_path(chave, pergunta), { lock_version: 0 } ],
      [ :patch, mover_configuracoes_formulario_rascunho_pergunta_path(chave, pergunta), { lock_version: 0, direcao: "abaixo" } ],
      [ :get, new_configuracoes_formulario_rascunho_publicacao_path(chave) ],
      [ :post, configuracoes_formulario_rascunho_publicacao_path(chave), { lock_version: 0, publicacao: { confirma_dpo: "1", confirma_minimizacao: "1" } } ],
      [ :get, configuracoes_formulario_versao_path(chave, 1) ]
    ]
  end

  test "sem login, toda rota do gerador leva ao login" do
    rotas_do_gerador.each do |verbo, caminho, parametros|
      public_send(verbo, caminho, params: parametros)
      assert_redirected_to new_user_session_path, "#{verbo} #{caminho}"
    end
  end

  test "quem não é admin não entra em nenhuma rota do gerador, nem descobre se o formulário existe" do
    formularios(:acompanhamento).versoes.create!(numero: 2, estrutura: versoes_formulario(:acompanhamento_v1).estrutura)
    estado = -> { [ Formulario.count, VersaoFormulario.count, VersaoFormulario.maximum(:updated_at), Formulario.maximum(:updated_at) ] }
    antes = estado.call

    %i[operador consultor laboratorista sem_acesso].each do |papel|
      sign_in users(papel)
      (rotas_do_gerador + rotas_do_gerador("nao_existe", "nao_existe")).each do |verbo, caminho, parametros|
        public_send(verbo, caminho, params: parametros)
        assert_redirected_to root_path, "#{papel}: #{verbo} #{caminho}"
        assert_equal "Você não tem permissão para realizar esta ação.", flash[:alert], "#{papel}: #{verbo} #{caminho}"
      end
      get root_path
      assert_select "a[href='#{configuracoes_formularios_path}']", 0
    end
    assert_equal antes, estado.call
  end

  test "nenhum texto digitado no gerador vira HTML, em nenhuma tela" do
    formulario = publicar_pelo_gerador(ATAQUE)
    controladora, dependente = formulario.definicao.chaves
    # Já está no ambulatório, escolhido na criação
    users(:operador).liberacoes_formulario.create!(setor: setores(:ambulatorio), formulario: formulario.chave, papel: "registra")

    # As telas do admin
    post configuracoes_formulario_rascunho_path(formulario)
    paginas = [
      configuracoes_formularios_path, configuracoes_formulario_path(formulario), configuracoes_formulario_rascunho_path(formulario),
      previa_configuracoes_formulario_rascunho_path(formulario), new_configuracoes_formulario_rascunho_publicacao_path(formulario),
      configuracoes_formulario_versao_path(formulario, 1), edit_configuracoes_formulario_rascunho_pergunta_path(formulario, controladora),
      remover_configuracoes_formulario_rascunho_pergunta_path(formulario, controladora),
      edit_configuracoes_formulario_rascunho_secao_path(formulario, "s1"),
      new_configuracoes_formulario_rascunho_pergunta_path(formulario, controladora:),
      edit_configuracoes_instituicao_setor_path(setores(:ambulatorio).instituicao, setores(:ambulatorio)),
      edit_configuracoes_usuario_liberacoes_path(users(:operador)), privacidade_path, root_path
    ]
    paginas.each { |pagina| assert_sem_html(pagina) }

    # As de quem preenche, inclusive com o texto nas respostas
    sign_in users(:operador)
    post formulario_avaliacoes_clinicas_path(formulario), params: {
      paciente: { prontuario_sah: "SAH-XSS", prontuario_aghuse: "", iniciais: "XSS" },
      avaliacao_clinica: { versao_formulario_id: formulario.versao_publicada_id, setor_id: setores(:ambulatorio).id,
                           dados_formulario: { controladora => "1", dependente => ATAQUE } }
    }
    avaliacao = AvaliacaoClinica.order(:id).last
    assert_equal ATAQUE, avaliacao.respostas[dependente]
    [ formulario_avaliacoes_clinicas_path(formulario), new_formulario_avaliacao_clinica_path(formulario),
      formulario_avaliacao_clinica_path(formulario, avaliacao), edit_formulario_avaliacao_clinica_path(formulario, avaliacao),
      root_path, privacidade_path ].each { |pagina| assert_sem_html(pagina) }
  end

  test "o gerador só aceita o que a tela pede: chave, estrutura, condição e versão não vêm de fora" do
    sign_in users(:admin)
    post configuracoes_formularios_path, params: { formulario: { titulo: "Teste", **destino_do_formulario, chave: "escolhida", versao_publicada_id: 1,
                                                                 estrutura: { "titulo" => "injetada" } } }
    formulario = Formulario.order(:id).last
    assert_equal "teste", formulario.chave
    assert_nil formulario.versao_publicada_id
    assert_equal "Teste", formulario.rascunho.definicao.titulo

    lock = -> { formulario.reload.rascunho.lock_version }
    patch configuracoes_formulario_rascunho_path(formulario), params: {
      lock_version: lock.call, cabecalho: { titulo: "Teste", numeracao: "automatica", secoes: [ { "id" => "s9", "titulo" => "Injetada" } ],
                                           publicada_em: Time.current, numero: 99 }
    }
    rascunho = formulario.reload.rascunho
    assert_empty rascunho.definicao.secoes
    assert_equal 1, rascunho.numero
    assert rascunho.rascunho?

    post configuracoes_formulario_rascunho_secoes_path(formulario), params: { lock_version: lock.call, secao: { titulo: "Seção", id: "s77", perguntas: [ "x" ] } }
    assert_equal [ "s1" ], formulario.reload.rascunho.definicao.secoes.map(&:id)
    post configuracoes_formulario_rascunho_perguntas_path(formulario), params: {
      lock_version: lock.call, secao: "s1",
      pergunta: { texto: "Campo", tipo: "texto", chave: "escolhida", condicao: { pergunta: "x", valores: [ "1" ] }, estrutura: "x" }
    }
    pergunta = formulario.reload.rascunho.definicao.perguntas.first
    assert_equal "campo", pergunta.chave
    assert_nil pergunta.condicao

    post configuracoes_formulario_rascunho_perguntas_path(formulario), params: { lock_version: lock.call, secao: "s1", pergunta: { texto: "Arquivo", tipo: "arquivo" } }
    assert_response :unprocessable_content
    assert_select "#pergunta_tipo_erros", text: /escolha um tipo da lista/

    # Seção e pergunta controladora inexistentes (ou de texto) dão 404
    get new_configuracoes_formulario_rascunho_pergunta_path(formulario, secao: "s9")
    assert_response :not_found
    get new_configuracoes_formulario_rascunho_pergunta_path(formulario, controladora: "campo")
    assert_response :not_found
    get edit_configuracoes_formulario_rascunho_secao_path(formulario, "s9")
    assert_response :not_found
  end

  test "limites: opções demais, texto grande e limite fora da faixa são recusados pela tela" do
    sign_in users(:admin)
    formulario = criar_rascunho_com_secao
    [
      [ { texto: "Muitas", tipo: "unica", opcoes: (1..101).map { |indice| "#{indice}, Opção #{indice}" }.join("\n") }, :opcoes, /no máximo 100 opções/ ],
      [ { texto: "x" * 501, tipo: "texto" }, :texto, /no máximo 500 caracteres/ ],
      [ { texto: "Longo", tipo: "texto_longo", limite: "5001" }, :limite, /de 1 a 5000/ ],
      [ { texto: "Rótulo", tipo: "unica", opcoes: "1, #{"x" * 201}" }, :opcoes, /o rótulo tem mais de 200 caracteres/ ],
      [ { texto: "Código", tipo: "unica", opcoes: "<b>, Negrito" }, :opcoes, /o código usa até 16 letras/ ]
    ].each do |campos, campo, mensagem|
      post configuracoes_formulario_rascunho_perguntas_path(formulario), params: {
        lock_version: formulario.reload.rascunho.lock_version, secao: "s1", pergunta: campos
      }
      assert_response :unprocessable_content
      assert_select "#pergunta_#{campo}_erros", text: mensagem
    end
    assert_empty formulario.reload.rascunho.definicao.perguntas
  end

  test "caracteres invisíveis e de direção do texto são tirados ao gravar" do
    sign_in users(:admin)
    formulario = criar_rascunho_com_secao
    post configuracoes_formulario_rascunho_perguntas_path(formulario), params: {
      lock_version: formulario.reload.rascunho.lock_version, secao: "s1",
      pergunta: { texto: "Nome‮ falso​", tipo: "unica", opcoes: "1, Sim⁦\n2, Não" }
    }
    pergunta = formulario.reload.rascunho.definicao.perguntas.first
    assert_equal "Nome falso", pergunta.texto
    assert_equal %w[Sim Não], pergunta.opcoes.map(&:rotulo)
    assert_not_includes formulario.rascunho.read_attribute_before_type_cast(:estrutura), "\\u202e"
  end

  test "envio sem o token CSRF é recusado no gerador" do
    ActionController::Base.allow_forgery_protection = true
    sign_in users(:admin)

    assert_no_difference -> { Formulario.count } do
      post configuracoes_formularios_path, params: { formulario: { titulo: "Sem token" } }
    end
    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "formulário nunca publicado não é preenchido, listado nem liberado, mesmo já num setor" do
    sign_in users(:admin)
    formulario = criar_rascunho_com_secao
    setor = setores(:ambulatorio)
    # Os setores são escolhidos já na criação, mas só valem depois de publicado
    assert FormularioHabilitado.exists?(setor:, formulario: formulario.chave)

    get formulario_avaliacoes_clinicas_path(formulario)
    assert_response :not_found
    get new_formulario_avaliacao_clinica_path(formulario)
    assert_response :not_found
    get root_path
    assert_select "nav[aria-label='Seções do sistema'] a", text: "Rascunho de teste", count: 0
    assert_nil users(:admin).permissoes.papel(setor.id, formulario.chave)

    # Nem a tela de liberações mostra, nem a liberação enviada à mão grava
    operador = users(:operador)
    get edit_configuracoes_usuario_liberacoes_path(operador)
    assert_select "input[name*='#{formulario.chave}']", 0
    patch configuracoes_usuario_liberacoes_path(operador), params: { liberacoes: {
      instituicoes: [ setor.instituicao_id ], setores: [ setor.id ], formularios: { setor.id.to_s => { "acompanhamento" => "registra", formulario.chave => "registra" } }
    } }
    assert_not operador.liberacoes_formulario.exists?(formulario: formulario.chave)
    assert_nil operador.reload.permissoes.papel(setor.id, formulario.chave)
  end

  test "não há versão JSON das telas do gerador" do
    sign_in users(:admin)
    # Uma página antes: a resposta de erro (406) não grava a sessão aberta pelo sign_in
    get configuracoes_formularios_path
    get configuracoes_formularios_path(format: :json)
    assert_response :not_acceptable
    get configuracoes_formulario_path(formularios(:acompanhamento), format: :json)
    assert_response :not_acceptable
  end

  test "criar e publicar ficam na auditoria com o autor, sem cópia do rascunho a cada passo" do
    sign_in users(:admin)
    formulario = publicar_pelo_gerador("Auditado")

    criado = PaperTrail::Version.find_by!(item: formulario, event: "create")
    assert_equal users(:admin).id.to_s, criado.whodunnit
    versoes = PaperTrail::Version.where(item_type: "VersaoFormulario", item_id: formulario.versao_publicada_id)
    assert versoes.where(event: "update").any? { |versao| versao.object_changes.include?("publicada_em") }
    assert versoes.all? { |versao| versao.whodunnit == users(:admin).id.to_s }
    assert versoes.none? { |versao| versao.object.to_s.include?("Auditado") || versao.object_changes.to_s.include?("Auditado") }
  end

  test "a tela de login não lista os formulários da instituição" do
    get new_user_session_path

    assert_response :success
    assert_not_includes response.body, formularios(:acompanhamento).titulo
  end

  private

  # O texto aparece escapado: nenhum elemento script, nenhuma imagem e nenhum
  # atributo de evento (on...) na página, e as tags do ataque só como texto
  def assert_sem_html(pagina)
    get pagina
    assert_response :success, pagina
    # O único script do sistema é o do botão Imprimir (arquivo do próprio site);
    # qualquer outro, ou um <img>, é HTML vindo do texto digitado
    corpo = response.body.gsub(%r{<script src="/assets/imprimir-[0-9a-f]+\.js" defer="defer"></script>}, "")
    assert_no_match %r{<script|<img}i, corpo, pagina
    documento = Nokogiri::HTML5(corpo)
    assert_empty documento.css("script, img"), pagina
    eventos = documento.xpath("//@*").select { |atributo| atributo.name.start_with?("on") }
    assert_empty eventos.map(&:name), pagina
    assert_includes response.body, "&lt;script&gt;", "o texto do ataque aparece escapado em #{pagina}"
  end

  def criar_rascunho_com_secao
    post configuracoes_formularios_path, params: { formulario: { titulo: "Rascunho de teste", **destino_do_formulario } }
    formulario = Formulario.order(:id).last
    post configuracoes_formulario_rascunho_secoes_path(formulario), params: { lock_version: formulario.rascunho.lock_version, secao: { titulo: "Primeira" } }
    formulario
  end

  # Um formulário com o texto em todos os campos que o gerador aceita, publicado pela tela
  def publicar_pelo_gerador(texto)
    sign_in users(:admin)
    post configuracoes_formularios_path, params: { formulario: { titulo: "#{texto} título", **destino_do_formulario } }
    formulario = Formulario.order(:id).last
    lock = -> { formulario.reload.rascunho.lock_version }
    patch configuracoes_formulario_rascunho_path(formulario), params: { lock_version: lock.call, cabecalho: {
      titulo: "#{texto} título", descricao: "#{texto} descrição", finalidade: "#{texto} finalidade", base_legal: "#{texto} base legal",
      numeracao: "automatica", encerramento: "", lista: [ "" ]
    } }
    post configuracoes_formulario_rascunho_secoes_path(formulario), params: { lock_version: lock.call, secao: { titulo: "#{texto} seção", descricao: "#{texto} descrição" } }
    post configuracoes_formulario_rascunho_perguntas_path(formulario), params: { lock_version: lock.call, secao: "s1", pergunta: {
      texto: "Pergunta #{texto}", tipo: "unica", ajuda: "#{texto} ajuda", opcoes: "1, #{texto} sim\n2, Não", obrigatoria: ""
    } }
    controladora = formulario.reload.rascunho.definicao.chaves.first
    post configuracoes_formulario_rascunho_perguntas_path(formulario), params: { lock_version: lock.call, controladora:, pergunta: {
      texto: "Detalhe #{texto}", tipo: "texto_longo", ajuda: texto, valores: [ "1" ]
    } }
    patch configuracoes_formulario_rascunho_path(formulario), params: { lock_version: lock.call, cabecalho: {
      titulo: "#{texto} título", descricao: "#{texto} descrição", finalidade: "#{texto} finalidade", base_legal: "#{texto} base legal",
      numeracao: "automatica", encerramento: "", lista: [ controladora ]
    } }
    post configuracoes_formulario_rascunho_publicacao_path(formulario), params: {
      lock_version: lock.call, publicacao: { confirma_dpo: "1", confirma_minimizacao: "1" }
    }
    assert formulario.reload.publicado?, "o formulário de teste não foi publicado"
    assert_equal 2, formulario.definicao.perguntas.size
    formulario
  end
end
