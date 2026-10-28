require "test_helper"

# Cada formulário pertence a uma instituição e vale só nos setores dela que o
# admin escolhe, já na criação. A tela do formulário altera os setores e
# mostra o movimento de cada um e o histórico de quem incluiu ou tirou.
class FormularioDaInstituicaoTest < ActionDispatch::IntegrationTest
  FORMULARIO = "acompanhamento".freeze

  setup do
    @centro = instituicoes(:centro)
    @hospital = instituicoes(:hospital)
    @ambulatorio = setores(:ambulatorio)
    @laboratorio = setores(:laboratorio)
    sign_in users(:admin)
  end

  test "a criação exige a instituição e um setor dela; setor de outra instituição é ignorado" do
    enfermaria = @hospital.setores.create!(nome: "Enfermaria")

    assert_no_difference -> { Formulario.count } do
      post configuracoes_formularios_path, params: { formulario: { titulo: "Triagem" } }
      assert_select "div[role=alert] li", text: "Escolha a instituição do formulário."

      post configuracoes_formularios_path, params: { formulario: { titulo: "Triagem", instituicao_id: @centro.id, setor_ids: [ "" ] } }
      assert_select "div[role=alert] li", text: /Marque pelo menos um setor/

      # Só um setor do hospital, com o centro escolhido: nenhum setor do centro
      post configuracoes_formularios_path, params: { formulario: { titulo: "Triagem", instituicao_id: @centro.id, setor_ids: [ enfermaria.id ] } }
      assert_response :unprocessable_content
    end
    # O modal volta aberto, com o que foi escolhido
    assert_select "dialog.modal input[type=radio][name='formulario[instituicao_id]'][value='#{@centro.id}'][checked]"
    assert_select "dialog.modal input[name='formulario[setor_ids][]'][value='#{enfermaria.id}'][checked]"

    post configuracoes_formularios_path, params: { formulario: { titulo: "Triagem", instituicao_id: @centro.id,
                                                                 setor_ids: [ "", @ambulatorio.id, enfermaria.id ] } }
    formulario = Formulario.find_by!(chave: "triagem")
    assert_equal @centro, formulario.instituicao
    assert_equal [ @ambulatorio.id ], formulario.habilitacoes.map(&:setor_id)
  end

  test "a criação abre num modal, com as instituições e os setores de cada uma" do
    get new_configuracoes_formulario_path

    assert_select "div[inert] table"
    assert_select "dialog.modal" do
      assert_select "h1", "Novo formulário"
      assert_select ".instituicao-do-formulario", 2
      assert_select ".instituicao-do-formulario input[type=radio][name='formulario[instituicao_id]'][value='#{@centro.id}']"
      assert_select ".instituicao-do-formulario .setores-da-instituicao input[role=switch][name='formulario[setor_ids][]']" \
                    "[value='#{@ambulatorio.id}'][aria-labelledby~='do_formulario_instituicao_#{@centro.id}_titulo']"
    end
  end

  test "na tela do formulário, o admin troca os setores; tirar de um setor tira as liberações dele" do
    enfermaria = @centro.setores.create!(nome: "Enfermaria")
    formularios(:acompanhamento).habilitar_em([ @ambulatorio.id, @laboratorio.id, enfermaria.id ])
    users(:operador).liberacoes_formulario.create!(setor: enfermaria, formulario: FORMULARIO, papel: "registra")

    patch configuracoes_formulario_setores_path(FORMULARIO), params: { formulario: { setor_ids: [ "", @ambulatorio.id, @laboratorio.id ] } }

    assert_redirected_to configuracoes_formulario_path(FORMULARIO, anchor: "setores")
    assert_equal "Setores do formulário salvos.", flash[:notice]
    assert_equal [ @ambulatorio.id, @laboratorio.id ].sort, formularios(:acompanhamento).habilitacoes.map(&:setor_id).sort
    assert_not LiberacaoFormulario.exists?(setor: enfermaria, formulario: FORMULARIO)
  end

  test "setor com notificações do formulário não sai, e nada muda" do
    enfermaria = @centro.setores.create!(nome: "Enfermaria")

    # O laboratório tem notificação do FORMULARIO: o pedido inteiro é recusado
    patch configuracoes_formulario_setores_path(FORMULARIO), params: { formulario: { setor_ids: [ "", @ambulatorio.id, enfermaria.id ] } }

    assert_match(/tem notificações neste setor/, flash[:alert])
    assert_equal [ @ambulatorio.id, @laboratorio.id ].sort, formularios(:acompanhamento).habilitacoes.map(&:setor_id).sort
  end

  test "a instituição só muda enquanto o formulário não está em nenhum setor" do
    formulario = publicar_formulario("triagem")
    formulario.habilitar_em([ @ambulatorio.id ])
    @hospital.setores.create!(nome: "Enfermaria")

    # Com setor, a troca é recusada
    patch configuracoes_formulario_setores_path(formulario), params: { formulario: { instituicao_id: @hospital.id, setor_ids: [ @ambulatorio.id ] } }
    assert_match(/só muda enquanto o formulário não está em nenhum setor/, flash[:alert])
    assert_equal @centro, formulario.reload.instituicao

    # Sem setores, a tela oferece as instituições e a troca vale
    formulario.habilitar_em([])
    get configuracoes_formulario_path(formulario)
    assert_select "form#setores input[type=radio][name='formulario[instituicao_id]'][value='#{@hospital.id}']"
    enfermaria = @hospital.setores.find_by!(nome: "Enfermaria")
    patch configuracoes_formulario_setores_path(formulario), params: { formulario: { instituicao_id: @hospital.id, setor_ids: [ "", enfermaria.id ] } }
    assert_equal @hospital, formulario.reload.instituicao
    assert_equal [ enfermaria.id ], formulario.habilitacoes.map(&:setor_id)
  end

  test "só o admin altera os setores de um formulário" do
    %i[operador consultor].each do |papel|
      sign_in users(papel)
      patch configuracoes_formulario_setores_path(FORMULARIO), params: { formulario: { setor_ids: [ "" ] } }
      assert_redirected_to root_path, papel
    end
    assert_equal 2, formularios(:acompanhamento).habilitacoes.count
  end

  test "a tela mostra o movimento de cada setor e avisa o setor parado" do
    ultimo = AvaliacaoClinica.where(formulario: FORMULARIO, setor: @ambulatorio).maximum(:created_at)

    travel_to ultimo + 10.days do
      get configuracoes_formulario_path(FORMULARIO)
      assert_select "label[for='do_formulario_setor_#{@ambulatorio.id}']", text: /2 notificações · último registro em/
      assert_select "label[for='do_formulario_setor_#{@ambulatorio.id}']", text: /Parado/, count: 0
    end

    travel_to ultimo + 31.days do
      # A sessão anterior expirou nesse meio-tempo: uma nova, do zero
      reset!
      sign_in users(:admin)
      get configuracoes_formulario_path(FORMULARIO)
      assert_select "label[for='do_formulario_setor_#{@ambulatorio.id}']", text: /Parado há mais de 30 dias/
      # O interruptor diz o estado e lê junto o movimento
      assert_select "input#do_formulario_setor_#{@ambulatorio.id}[role=switch][checked][aria-describedby='do_formulario_setor_#{@ambulatorio.id}_subtitulo']"
    end
  end

  test "o histórico mostra quem incluiu e quem tirou o formulário de cada setor" do
    enfermaria = @centro.setores.create!(nome: "Enfermaria")
    patch configuracoes_formulario_setores_path(FORMULARIO), params: { formulario: { setor_ids: [ @ambulatorio.id, @laboratorio.id, enfermaria.id ] } }
    patch configuracoes_formulario_setores_path(FORMULARIO), params: { formulario: { setor_ids: [ @ambulatorio.id, @laboratorio.id ] } }

    eventos = AcompanhamentoDoFormulario.new(formularios(:acompanhamento)).historico
    assert_equal [ :tirou, :incluiu ], eventos.first(2).map(&:acao)
    assert_equal [ enfermaria, enfermaria ], eventos.first(2).map(&:setor)
    assert_equal [ users(:admin) ] * 2, eventos.first(2).map(&:autor)

    get configuracoes_formulario_path(FORMULARIO)
    assert_select "section#historico li", text: /@admin_teste\s+tirou do setor\s+CRF - Enfermaria/
    assert_select "section#historico li", text: /@admin_teste\s+incluiu no setor\s+CRF - Enfermaria/
  end

  test "formulário habilitado noutra instituição antes da regra continua lá, mas não entra em setor novo de fora" do
    # Como a migração deixa um formulário que já estava em duas instituições
    enfermaria = @hospital.setores.create!(nome: "Enfermaria")
    FormularioHabilitado.insert!({ setor_id: enfermaria.id, formulario: FORMULARIO, created_at: Time.current, updated_at: Time.current })
    formulario = formularios(:acompanhamento)

    get configuracoes_formulario_path(FORMULARIO)
    assert_select "label[for='do_formulario_setor_#{enfermaria.id}']", text: /De outra instituição \(anterior à regra\)/
    get edit_configuracoes_instituicao_setor_path(@hospital, enfermaria)
    assert_select "input[name='setor[formularios][]'][value='#{FORMULARIO}'][checked]"

    # Salvar sem mexer mantém; uma habilitação nova de fora é recusada
    assert formulario.habilitar_em([ @ambulatorio.id, @laboratorio.id, enfermaria.id ])
    assert FormularioHabilitado.exists?(setor: enfermaria, formulario: FORMULARIO)
    triagem = @hospital.setores.create!(nome: "Triagem")
    assert_not FormularioHabilitado.new(setor: triagem, formulario: FORMULARIO).valid?
    formulario.habilitar_em([ @ambulatorio.id, @laboratorio.id, enfermaria.id, triagem.id ])
    assert_not FormularioHabilitado.exists?(setor: triagem, formulario: FORMULARIO)
  end

  test "instituição com formulários não é excluída" do
    assert_not @hospital.formularios.exists?
    publicar_formulario("do_hospital").update!(instituicao: @hospital)

    get edit_configuracoes_instituicao_path(@hospital)
    assert_select "p", text: "Tem formulários: não pode ser excluída."
    assert_select "button[form='excluir_instituicao']", 0

    delete configuracoes_instituicao_path(@hospital)
    assert Instituicao.exists?(@hospital.id)
  end
end
