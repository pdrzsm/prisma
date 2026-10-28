require "test_helper"

# O gerador de formulários pela tela, como o admin usa: criar, montar seções e
# perguntas de cada tipo (inclusive as que dependem de outra), revisar,
# publicar, liberar e preencher; depois mudar o formulário e ver que as
# notificações antigas continuam com a versão delas.
class GeradorDeFormulariosTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin) }

  test "do zero até a notificação, e uma versão nova que não mexe na notificação antiga" do
    get configuracoes_formularios_path
    assert_response :success
    assert_select "nav[aria-label='Seções do sistema'] a[aria-current='page']", text: /Gerador de formulários/

    post configuracoes_formularios_path, params: { formulario: { titulo: "Avaliação nutricional", **destino_do_formulario } }
    formulario = Formulario.find_by!(chave: "avaliacao_nutricional")
    assert_redirected_to configuracoes_formulario_rascunho_path(formulario)
    assert_not formulario.publicado?
    follow_redirect!
    assert_response :success

    post configuracoes_formulario_rascunho_secoes_path(formulario), params: { lock_version: lock(formulario), secao: { titulo: "Medidas", descricao: "Na consulta." } }
    assert_redirected_to configuracoes_formulario_rascunho_path(formulario, anchor: "s1")

    criar_pergunta formulario, secao: "s1", texto: "Peso", tipo: "numero", decimais: "1", minimo: "1", maximo: "300", obrigatoria: "abertura"
    criar_pergunta formulario, secao: "s1", texto: "Dieta", tipo: "lista_suspensa", opcoes: "1, Livre\n2, Restrita"
    criar_pergunta formulario, controladora: "dieta", texto: "Qual restrição?", tipo: "multipla",
                               opcoes: "1, Sem sal\n2, Sem açúcar\n9, Outra", valores: [ "2" ]
    criar_pergunta formulario, controladora: "qual_restricao", texto: "Descreva a outra", tipo: "texto_longo", limite: "300", valores: [ "9" ]

    rascunho = formulario.reload.rascunho
    assert_equal %w[peso dieta qual_restricao descreva_a_outra], rascunho.definicao.chaves
    assert_equal [ 0, 0, 1, 2 ], rascunho.definicao.perguntas.map(&:profundidade)

    get configuracoes_formulario_rascunho_path(formulario)
    assert_select "li#pergunta-qual_restricao p", text: /Aparece quando “Dieta” for:\s+Restrita/
    get previa_configuracoes_formulario_rascunho_path(formulario)
    assert_response :success
    assert_select "main form", 0 # a prévia não envia nada (o único form da página é a busca do cabeçalho)
    assert_select "select[name='avaliacao_clinica[dados_formulario][dieta]'] option[value='2'][data-revela='1']"

    # Sem finalidade e base legal, não publica
    get new_configuracoes_formulario_rascunho_publicacao_path(formulario)
    assert_select "div[role=alert] li", text: "Finalidade: falta preencher."
    assert_select "input[type=submit][value^='Publicar']", 0
    post configuracoes_formulario_rascunho_publicacao_path(formulario), params: publicacao(formulario)
    assert_response :unprocessable_content
    assert_not formulario.reload.publicado?

    patch configuracoes_formulario_rascunho_path(formulario), params: { lock_version: lock(formulario), cabecalho: cabecalho(titulo: "Avaliação nutricional") }
    assert_redirected_to configuracoes_formulario_rascunho_path(formulario, anchor: "cabecalho")

    # Sem as duas confirmações, também não
    post configuracoes_formulario_rascunho_publicacao_path(formulario), params: publicacao(formulario, confirma_dpo: "0")
    assert_response :unprocessable_content
    assert_not formulario.reload.publicado?

    post configuracoes_formulario_rascunho_publicacao_path(formulario), params: publicacao(formulario)
    assert_redirected_to configuracoes_formulario_path(formulario)
    formulario.reload
    assert_equal 1, formulario.versao_publicada.numero
    assert_equal users(:admin), formulario.versao_publicada.publicada_por
    assert_nil formulario.rascunho

    # O admin habilita no setor e libera o operador
    setor = setores(:ambulatorio)
    patch configuracoes_instituicao_setor_path(setor.instituicao, setor), params: { setor: { nome: setor.nome, formularios: [ "acompanhamento", formulario.chave ] } }
    patch configuracoes_usuario_liberacoes_path(users(:operador)), params: { liberacoes: {
      instituicoes: [ setor.instituicao_id ], setores: [ setor.id ], formularios: { setor.id.to_s => { "acompanhamento" => "registra", formulario.chave => "registra" } }
    } }
    assert users(:operador).reload.permissoes.registra?(setor.id, formulario.chave)

    sign_in users(:operador)
    get new_formulario_avaliacao_clinica_path(formulario)
    assert_response :success
    assert_select "nav a", text: "Avaliação nutricional"
    post formulario_avaliacoes_clinicas_path(formulario), params: {
      paciente: { prontuario_sah: "SAH-NUTRI", prontuario_aghuse: "", iniciais: "NT" },
      avaliacao_clinica: { versao_formulario_id: formulario.versao_publicada_id, setor_id: setor.id,
                           dados_formulario: { "peso" => "72,5", "dieta" => "2", "qual_restricao" => [ "", "9" ], "descreva_a_outra" => "Sem glúten" } }
    }
    antiga = AvaliacaoClinica.order(:id).last
    assert_redirected_to formulario_avaliacao_clinica_path(formulario, antiga)
    assert_equal({ "peso" => "72.5", "dieta" => "2", "qual_restricao" => [ "9" ], "descreva_a_outra" => "Sem glúten" }, antiga.respostas)

    # Versão 2: a pergunta da restrição muda de opções e o peso sai
    sign_in users(:admin)
    post configuracoes_formulario_rascunho_path(formulario)
    assert_redirected_to configuracoes_formulario_rascunho_path(formulario)
    patch configuracoes_formulario_rascunho_pergunta_path(formulario, "qual_restricao"), params: {
      lock_version: lock(formulario), pergunta: pergunta(texto: "Qual restrição?", tipo: "multipla", opcoes: "1, Sem sal\n2, Sem açúcar\n3, Sem glúten\n9, Outra", valores: [ "", "2" ])
    }
    delete configuracoes_formulario_rascunho_pergunta_path(formulario, "peso"), params: { lock_version: lock(formulario) }
    get new_configuracoes_formulario_rascunho_publicacao_path(formulario)
    assert_select "li", text: /Peso/ # perguntas removidas
    assert_select "li", text: /opção nova: 3, Sem glúten/
    post configuracoes_formulario_rascunho_publicacao_path(formulario), params: publicacao(formulario)
    assert_equal 2, formulario.reload.versao_publicada.numero

    # A notificação antiga continua na versão 1, com o peso, na tela e na edição
    sign_in users(:operador)
    get formulario_avaliacao_clinica_path(formulario, antiga)
    assert_includes response.body, "72,5"
    assert_includes response.body, "Versão 1 do formulário"
    get edit_formulario_avaliacao_clinica_path(formulario, antiga)
    assert_select "input[name='avaliacao_clinica[dados_formulario][peso]'][value='72.5']"
    patch formulario_avaliacao_clinica_path(formulario, antiga), params: {
      avaliacao_clinica: { lock_version: antiga.reload.lock_version, dados_formulario: antiga.respostas.merge("peso" => "73") }
    }
    assert_equal "73", antiga.reload.respostas["peso"]
    assert_equal 1, antiga.versao_formulario.numero

    # E a nova já nasce na versão 2, sem o peso
    get new_formulario_avaliacao_clinica_path(formulario)
    assert_select "[name='avaliacao_clinica[dados_formulario][peso]']", 0
  end

  test "título em branco volta com o erro" do
    assert_no_difference -> { Formulario.count } do
      post configuracoes_formularios_path, params: { formulario: { titulo: "  ", **destino_do_formulario } }
    end
    assert_response :unprocessable_content
    assert_select "div[role=alert] li", text: /Título do formulário: falta preencher/
  end

  test "erro de uma pergunta aparece ao lado do campo e nada é gravado" do
    formulario = rascunho_com_secao
    antes = formulario.reload.rascunho.estrutura

    post configuracoes_formulario_rascunho_perguntas_path(formulario), params: {
      lock_version: lock(formulario), secao: "s1", pergunta: pergunta(texto: "", tipo: "unica", opcoes: "Sim\n2, Não\n2, Talvez")
    }
    assert_response :unprocessable_content
    assert_select "#pergunta_texto_erros", text: /não pode ficar em branco/
    assert_select "#pergunta_opcoes_erros", text: /linha 1: use o formato código, rótulo/
    assert_select "#pergunta_opcoes_erros", text: /há códigos repetidos/
    assert_select "textarea#pergunta_opcoes", text: /Talvez/ # o que foi digitado continua lá
    assert_equal antes, formulario.reload.rascunho.estrutura
  end

  test "erro da definição inteira (que só a gravação vê) também volta para a tela" do
    formulario = rascunho_com_secao
    criar_pergunta formulario, secao: "s1", texto: "Cor", tipo: "unica", opcoes: "1, Azul\n2, Verde"
    criar_pergunta formulario, controladora: "cor", texto: "Tom", tipo: "texto", valores: [ "1" ]

    # Tirar a opção que a dependente usa deixaria a condição apontando para nada
    patch configuracoes_formulario_rascunho_pergunta_path(formulario, "cor"), params: {
      lock_version: lock(formulario), pergunta: pergunta(texto: "Cor", tipo: "unica", opcoes: "2, Verde")
    }
    assert_response :unprocessable_content
    assert_select "div[role=alert] li", text: /a condição usa opções que “Cor” não tem/
    assert_equal %w[1 2], formulario.reload.rascunho.definicao.pergunta("cor").codigos
  end

  test "mudar, mover e remover seções e perguntas" do
    formulario = rascunho_com_secao
    post configuracoes_formulario_rascunho_secoes_path(formulario), params: { lock_version: lock(formulario), secao: { titulo: "Segunda", descricao: "" } }
    criar_pergunta formulario, secao: "s1", texto: "Primeira pergunta", tipo: "texto"
    criar_pergunta formulario, secao: "s1", texto: "Escolha", tipo: "unica", opcoes: "1, Sim\n2, Não"
    criar_pergunta formulario, controladora: "escolha", texto: "Detalhe", tipo: "texto", valores: [ "1" ]

    # A pergunta de escolha sobe levando a dependente junto
    patch mover_configuracoes_formulario_rascunho_pergunta_path(formulario, "escolha"), params: { lock_version: lock(formulario), direcao: "acima" }
    assert_equal %w[escolha detalhe primeira_pergunta], chaves(formulario)
    # A última da seção desce para a seção seguinte
    patch mover_configuracoes_formulario_rascunho_pergunta_path(formulario, "primeira_pergunta"), params: { lock_version: lock(formulario), direcao: "abaixo" }
    assert_equal [ %w[escolha detalhe], %w[primeira_pergunta] ], formulario.reload.rascunho.definicao.secoes.map { |secao| secao.perguntas.map(&:chave) }
    # A dependente não sai de perto da pergunta de que depende
    patch mover_configuracoes_formulario_rascunho_pergunta_path(formulario, "detalhe"), params: { lock_version: lock(formulario), direcao: "acima" }
    assert_redirected_to configuracoes_formulario_rascunho_path(formulario, anchor: "pergunta-detalhe")
    assert_equal "Não há para onde mover a pergunta.", flash[:alert]

    patch mover_configuracoes_formulario_rascunho_secao_path(formulario, "s2"), params: { lock_version: lock(formulario), direcao: "acima" }
    assert_equal %w[s2 s1], formulario.reload.rascunho.definicao.secoes.map(&:id)

    # Seção com perguntas não sai; vazia, sai
    delete configuracoes_formulario_rascunho_secao_path(formulario, "s1"), params: { lock_version: lock(formulario) }
    assert_equal 2, formulario.reload.rascunho.definicao.secoes.size
    get remover_configuracoes_formulario_rascunho_pergunta_path(formulario, "escolha")
    assert_select "li", text: /Detalhe \(depende de “Escolha”\)/
    delete configuracoes_formulario_rascunho_pergunta_path(formulario, "escolha"), params: { lock_version: lock(formulario) }
    assert_equal %w[primeira_pergunta], chaves(formulario)
    delete configuracoes_formulario_rascunho_secao_path(formulario, "s1"), params: { lock_version: lock(formulario) }
    assert_equal %w[s2], formulario.reload.rascunho.definicao.secoes.map(&:id)

    patch configuracoes_formulario_rascunho_secao_path(formulario, "s2"), params: { lock_version: lock(formulario), secao: { titulo: "Renomeada", descricao: "Com descrição" } }
    assert_equal "Renomeada", formulario.reload.rascunho.definicao.secoes.first.titulo
  end

  test "uma tela antiga (outra aba) não sobrescreve o rascunho" do
    formulario = rascunho_com_secao
    antigo = lock(formulario)
    criar_pergunta formulario, secao: "s1", texto: "Nova", tipo: "texto"

    post configuracoes_formulario_rascunho_perguntas_path(formulario), params: { lock_version: antigo, secao: "s1", pergunta: pergunta(texto: "Outra", tipo: "texto") }
    assert_redirected_to configuracoes_formulario_rascunho_path(formulario)
    assert_match "O rascunho mudou", flash[:alert]
    assert_equal %w[nova], chaves(formulario)

    # Sem lock_version, também não grava
    post configuracoes_formulario_rascunho_perguntas_path(formulario), params: { secao: "s1", pergunta: pergunta(texto: "Outra", tipo: "texto") }
    assert_match "O rascunho mudou", flash[:alert]
    assert_equal %w[nova], chaves(formulario)
  end

  test "publicar só o que foi revisto: se o rascunho mudou depois da revisão, não publica" do
    formulario = rascunho_com_secao
    criar_pergunta formulario, secao: "s1", texto: "Campo", tipo: "texto"
    patch configuracoes_formulario_rascunho_path(formulario), params: { lock_version: lock(formulario), cabecalho: cabecalho(titulo: "Teste") }
    revisto = lock(formulario)
    criar_pergunta formulario, secao: "s1", texto: "Mudança depois da revisão", tipo: "texto"

    post configuracoes_formulario_rascunho_publicacao_path(formulario), params: publicacao(formulario, lock_version: revisto)
    assert_redirected_to configuracoes_formulario_rascunho_path(formulario)
    assert_not formulario.reload.publicado?
  end

  test "descartar o rascunho de um formulário publicado mantém a versão publicada" do
    formulario = formularios(:acompanhamento)
    post configuracoes_formulario_rascunho_path(formulario)
    assert_equal 2, formulario.reload.rascunho.numero

    get descartar_configuracoes_formulario_rascunho_path(formulario)
    assert_response :success
    delete configuracoes_formulario_rascunho_path(formulario)
    assert_redirected_to configuracoes_formulario_path(formulario)
    assert_nil formulario.reload.rascunho
    assert_equal versoes_formulario(:acompanhamento_v1), formulario.versao_publicada
  end

  test "formulário nunca publicado é excluído inteiro, sem pedir a confirmação marcada" do
    formulario = rascunho_com_secao
    get excluir_configuracoes_formulario_path(formulario)
    assert_response :success
    assert_select "li", text: /O rascunho da versão 1/
    assert_select "input[type=checkbox][name=confirmo]", 0

    assert_difference -> { Formulario.count } => -1, -> { VersaoFormulario.count } => -1 do
      delete configuracoes_formulario_path(formulario)
    end
    assert_redirected_to configuracoes_formularios_path
    assert_match "excluído", flash[:notice]
    assert_equal users(:admin).id.to_s, PaperTrail::Version.where(item_type: "Formulario", event: "destroy").last.whodunnit
  end

  test "formulário publicado, sem notificações, também é excluído, depois de confirmar" do
    formulario = publicar_formulario("sem_uso")
    setores(:ambulatorio).formularios_habilitados.create!(formulario: "sem_uso")
    users(:operador).liberacoes_formulario.create!(setor: setores(:ambulatorio), formulario: "sem_uso", papel: "registra")

    # A lista e a tela do formulário oferecem o Excluir
    get configuracoes_formularios_path
    assert_select "a[href=?]", excluir_configuracoes_formulario_path(formulario), text: "Excluir"
    get configuracoes_formulario_path(formulario)
    assert_select "a[href=?]", excluir_configuracoes_formulario_path(formulario), text: "Excluir formulário"

    # A confirmação diz o que sai junto e pede a marcação
    get excluir_configuracoes_formulario_path(formulario)
    assert_response :success
    assert_select "li", text: /A versão 1, publicada em/
    assert_select "li", text: /A habilitação em .*Ambulatório/
    assert_select "li", text: /1 liberação de pessoas neste formulário/
    assert_select "input[type=checkbox][name=confirmo]"

    # Sem a marcação, nada sai e a tela volta com o aviso
    assert_no_difference [ -> { Formulario.count }, -> { VersaoFormulario.count }, -> { FormularioHabilitado.count }, -> { LiberacaoFormulario.count } ] do
      delete configuracoes_formulario_path(formulario)
    end
    assert_response :unprocessable_content
    assert_select "div[role=alert] li", text: /Marque a confirmação/

    assert_difference -> { Formulario.count } => -1, -> { VersaoFormulario.count } => -1, -> { FormularioHabilitado.count } => -1,
                      -> { LiberacaoFormulario.count } => -1 do
      delete configuracoes_formulario_path(formulario), params: { confirmo: "1" }
    end
    assert_redirected_to configuracoes_formularios_path
    assert_match "excluído. A exclusão ficou na auditoria", flash[:notice]
    assert_not Formulario.exists?(chave: "sem_uso")
    # O formulário some de quem o usava
    assert_not users(:operador).permissoes.formularios_consultados.map(&:chave).include?("sem_uso")
  end

  test "formulário com notificações não é excluído: a tela explica e nenhuma rota exclui" do
    acompanhamento = formularios(:acompanhamento)

    get configuracoes_formularios_path
    assert_select "a[href=?]", excluir_configuracoes_formulario_path(acompanhamento), 0
    get configuracoes_formulario_path(acompanhamento)
    assert_select "a", text: "Excluir formulário", count: 0
    assert_select "p", text: /tem 3 notificações e não pode ser excluído/

    get excluir_configuracoes_formulario_path(acompanhamento)
    assert_redirected_to configuracoes_formulario_path(acompanhamento)
    assert_match "tem 3 notificações e não pode ser excluído", flash[:alert]

    assert_no_difference [ -> { Formulario.count }, -> { VersaoFormulario.count }, -> { FormularioHabilitado.count } ] do
      delete configuracoes_formulario_path(acompanhamento), params: { confirmo: "1" }
    end
    assert_redirected_to configuracoes_formulario_path(acompanhamento)
    assert_match "não pode ser excluído", flash[:alert]
  end

  test "quem não é admin não exclui formulário nenhum, nem sem notificações" do
    formulario = publicar_formulario("sem_uso")
    sign_in users(:operador)

    assert_no_difference [ -> { Formulario.count }, -> { VersaoFormulario.count } ] do
      delete configuracoes_formulario_path(formulario), params: { confirmo: "1" }
    end
    assert_redirected_to root_path
    assert_equal "Você não tem permissão para realizar esta ação.", flash[:alert]
    get excluir_configuracoes_formulario_path(formulario)
    assert_redirected_to root_path
  end

  test "versão publicada: só consulta, sem rota para alterar ou excluir" do
    get configuracoes_formulario_versao_path(formularios(:acompanhamento), 1)
    assert_response :success
    assert_includes response.body, "Publicada em"
    assert_select "select, input[type=radio]", minimum: 1 # a prévia funciona

    patch "/configuracoes/formularios/acompanhamento/versoes/1"
    assert_response :not_found
    delete "/configuracoes/formularios/acompanhamento/versoes/1"
    assert_response :not_found
    get configuracoes_formulario_versao_path(formularios(:acompanhamento), 2)
    assert_response :not_found
  end

  test "o formulário publicado de novo enquanto alguém preenchia: a tela volta com a versão nova, sem gravar" do
    acompanhamento = formularios(:acompanhamento)
    nova = acompanhamento.versoes.create!(numero: 2, estrutura: acompanhamento.versao_publicada.estrutura)
    nova.publicar!(por: users(:admin))

    sign_in users(:operador)
    assert_no_difference -> { AvaliacaoClinica.count } do
      post formulario_avaliacoes_clinicas_path(acompanhamento), params: {
        paciente: { prontuario_sah: "SAH-NOVO", prontuario_aghuse: "", iniciais: "ABC" },
        avaliacao_clinica: { versao_formulario_id: versoes_formulario(:acompanhamento_v1).id, setor_id: setores(:ambulatorio).id,
                             dados_formulario: respostas_de_abertura("municipio_residencia" => "Digitado antes") }
      }
    end
    assert_response :unprocessable_content
    assert_match "O formulário foi atualizado enquanto você preenchia", flash[:alert]
    assert_select "input[name='avaliacao_clinica[versao_formulario_id]'][value='#{nova.id}']"
    assert_select "input[name='avaliacao_clinica[dados_formulario][municipio_residencia]'][value='Digitado antes']"
  end

  test "nova, editar e remover pergunta abrem num modal por cima do rascunho, com o lugar delas à vista atrás" do
    formulario = rascunho_com_secao
    criar_pergunta formulario, secao: "s1", texto: "Cor", tipo: "unica", opcoes: "1, Azul\n2, Verde"
    na_secao = configuracoes_formulario_rascunho_path(formulario, anchor: "s1")
    na_pergunta = configuracoes_formulario_rascunho_path(formulario, anchor: "pergunta-cor")

    # Os links do rascunho levam a âncora do lugar, para o fundo ficar nele
    get configuracoes_formulario_rascunho_path(formulario)
    assert_select "a[href=?]", new_configuracoes_formulario_rascunho_pergunta_path(formulario, secao: "s1", anchor: "s1"), text: "Nova pergunta nesta seção"
    assert_select "li#pergunta-cor a[href=?]", edit_configuracoes_formulario_rascunho_pergunta_path(formulario, "cor", anchor: "pergunta-cor"), text: "Editar"
    assert_select "li#pergunta-cor a[href=?]", remover_configuracoes_formulario_rascunho_pergunta_path(formulario, "cor", anchor: "pergunta-cor"), text: "Remover"
    assert_select "li#pergunta-cor a[href=?]", new_configuracoes_formulario_rascunho_pergunta_path(formulario, controladora: "cor", anchor: "pergunta-cor")
    assert_select "dialog.modal", 0

    [ [ new_configuracoes_formulario_rascunho_pergunta_path(formulario, secao: "s1"), "Nova pergunta", na_secao ],
      [ new_configuracoes_formulario_rascunho_pergunta_path(formulario, controladora: "cor"), "Nova pergunta", na_pergunta ],
      [ edit_configuracoes_formulario_rascunho_pergunta_path(formulario, "cor"), "Editar pergunta 1", na_pergunta ],
      [ remover_configuracoes_formulario_rascunho_pergunta_path(formulario, "cor"), "Remover do rascunho?", na_pergunta ] ].each do |caminho, titulo, voltar|
      get caminho
      assert_response :success, caminho
      assert_select "dialog.modal[open] h1#modal_titulo", text: titulo
      assert_select "dialog.modal[open] a[aria-label=Fechar][href=?]", voltar
      # O rascunho inteiro fica atrás, inerte (sem clique nem foco)
      assert_select "div[inert] details#cabecalho"
      assert_select "div[inert] section#s1 li#pergunta-cor"
    end

    # O formulário da pergunta tem as ações sempre à vista, fora da rolagem
    get new_configuracoes_formulario_rascunho_pergunta_path(formulario, secao: "s1")
    assert_select "dialog.modal form.pergunta-do-gerador" do
      assert_select "div.overflow-y-auto select.tipo-da-pergunta"
      assert_select "div.shrink-0 input[type=submit][value='Criar pergunta']"
      assert_select "div.shrink-0 a[href=?]", na_secao, text: "Cancelar"
    end
    get edit_configuracoes_formulario_rascunho_pergunta_path(formulario, "cor")
    assert_select "dialog.modal form.pergunta-do-gerador div.shrink-0 input[type=submit][value='Salvar pergunta']"
    get remover_configuracoes_formulario_rascunho_pergunta_path(formulario, "cor")
    assert_select "dialog.modal button", text: "Remover pergunta"
  end

  test "nova e editar seção abrem numa janela no centro da tela por cima do rascunho" do
    formulario = rascunho_com_secao
    na_secao = configuracoes_formulario_rascunho_path(formulario, anchor: "s1")

    # Os links do rascunho levam a âncora do lugar
    get configuracoes_formulario_rascunho_path(formulario)
    assert_select "a[href=?]", new_configuracoes_formulario_rascunho_secao_path(formulario, anchor: "s1"), text: "Nova seção"
    assert_select "a[href=?]", edit_configuracoes_formulario_rascunho_secao_path(formulario, "s1", anchor: "s1"), text: "Editar seção"

    get new_configuracoes_formulario_rascunho_secao_path(formulario)
    assert_response :success
    assert_select "dialog.modal[open].items-center.justify-center > section.max-w-lg" do
      assert_select "h1#modal_titulo", text: "Nova seção"
      assert_select "a[aria-label=Fechar][href=?]", na_secao
      assert_select "form input[name='secao[titulo]']"
      assert_select "div.shrink-0 input[type=submit][value='Criar seção']"
      assert_select "div.shrink-0 a[href=?]", na_secao, text: "Cancelar"
    end
    assert_select "div[inert] section#s1" # o rascunho, atrás, inerte

    # A seção vazia mostra o Remover no rodapé, que envia o formulário de fora (atributo form)
    get edit_configuracoes_formulario_rascunho_secao_path(formulario, "s1")
    assert_select "dialog.modal[open] h1#modal_titulo", text: "Editar seção"
    assert_select "dialog.modal div.shrink-0 button[form=remover_secao]", text: "Remover seção"
    assert_select "dialog.modal form#remover_secao[hidden][action=?]", configuracoes_formulario_rascunho_secao_path(formulario, "s1")
    assert_select "dialog.modal input[name='secao[titulo]'][value=Primeira]"

    # Com perguntas, não pode ser removida: sem o botão
    criar_pergunta formulario, secao: "s1", texto: "Uma pergunta", tipo: "texto"
    get edit_configuracoes_formulario_rascunho_secao_path(formulario, "s1")
    assert_select "dialog.modal button[form=remover_secao]", 0
    assert_select "dialog.modal form#remover_secao", 0
  end

  test "a seção com erro volta na janela, com o erro dentro dela e o que foi digitado" do
    formulario = rascunho_com_secao

    post configuracoes_formulario_rascunho_secoes_path(formulario), params: { lock_version: lock(formulario), secao: { titulo: "", descricao: "Sem título" } }
    assert_response :unprocessable_content
    assert_select "dialog.modal[open] div[role=alert]", text: /Não foi possível salvar/
    assert_select "dialog.modal[open] textarea[name='secao[descricao]']", text: /Sem título/
    assert_select "div[inert] div[role=alert]", 0 # o erro não se repete no rascunho de trás
    assert_equal [ "s1" ], formulario.reload.rascunho.definicao.secoes.map(&:id)
  end

  test "a pergunta com erro volta no modal, com o erro e o que foi digitado, e o rascunho continua atrás" do
    formulario = rascunho_com_secao

    post configuracoes_formulario_rascunho_perguntas_path(formulario), params: {
      lock_version: lock(formulario), secao: "s1", pergunta: pergunta(texto: "Sem opções", tipo: "unica", opcoes: "")
    }
    assert_response :unprocessable_content
    assert_select "dialog.modal[open] form.pergunta-do-gerador" do
      assert_select "#pergunta_opcoes_erros"
      assert_select "input[name='pergunta[texto]'][value='Sem opções']"
    end
    assert_select "div[inert] section#s1"
    # O erro aparece uma vez, no modal, e não de novo no rascunho de trás
    assert_select "div[inert] div[role=alert]", 0
  end

  test "o cabeçalho continua aberto logo depois de salvo e volta recolhido quando está completo" do
    formulario = rascunho_com_secao

    patch configuracoes_formulario_rascunho_path(formulario), params: { lock_version: lock(formulario), cabecalho: cabecalho(titulo: "Completo") }
    assert_redirected_to configuracoes_formulario_rascunho_path(formulario, anchor: "cabecalho")
    follow_redirect!
    assert_select "details#cabecalho[open] input[name='cabecalho[titulo]'][value='Completo']"
    assert_match "Cabeçalho salvo.", response.body

    # Em outra visita, com finalidade e base legal preenchidas, ele fica recolhido
    get configuracoes_formulario_rascunho_path(formulario)
    assert_select "details#cabecalho"
    assert_select "details#cabecalho[open]", 0
  end

  private

  def lock(formulario)
    formulario.reload.rascunho.lock_version
  end

  def chaves(formulario)
    formulario.reload.rascunho.definicao.chaves
  end

  def rascunho_com_secao
    post configuracoes_formularios_path, params: { formulario: { titulo: "Rascunho de teste", **destino_do_formulario } }
    formulario = Formulario.order(:id).last
    post configuracoes_formulario_rascunho_secoes_path(formulario), params: { lock_version: lock(formulario), secao: { titulo: "Primeira", descricao: "" } }
    formulario
  end

  def pergunta(**campos)
    { texto: "", tipo: "texto", ajuda: "", obrigatoria: "", limite: "", minimo: "", maximo: "", decimais: "0",
      nao_maior_que: "", nao_antes_de: "", permite_futuro: "0", opcoes: "", exclusivas: "" }.merge(campos)
  end

  def criar_pergunta(formulario, secao: nil, controladora: nil, valores: nil, **campos)
    post configuracoes_formulario_rascunho_perguntas_path(formulario), params: {
      # O campo escondido da tela manda um vazio antes das opções marcadas
      lock_version: lock(formulario), secao:, controladora:, pergunta: pergunta(**campos).merge({ valores: valores && [ "" ] + valores }.compact)
    }.compact
    assert_response :redirect, -> { Nokogiri::HTML5(response.body).css("[role=alert], [id$=_erros]").map(&:text).join(" | ") }
    assert_nil flash[:alert]
  end

  def cabecalho(titulo:)
    { titulo:, descricao: "", finalidade: "acompanhar o estado nutricional", base_legal: "tutela da saúde (LGPD, art. 11, II, “f”)",
      numeracao: "automatica", encerramento: "", lista: [ "" ] }
  end

  def publicacao(formulario, lock_version: lock(formulario), confirma_dpo: "1", confirma_minimizacao: "1")
    { lock_version:, publicacao: { confirma_dpo:, confirma_minimizacao: } }
  end
end
