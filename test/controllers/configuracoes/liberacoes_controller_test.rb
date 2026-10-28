require "test_helper"

module Configuracoes
  class LiberacoesControllerTest < ActionDispatch::IntegrationTest
    FORMULARIO = "acompanhamento".freeze

    setup do
      @centro = instituicoes(:centro)
      @ambulatorio = setores(:ambulatorio)
      @laboratorio = setores(:laboratorio)
      @pessoa = users(:sem_acesso)
    end

    test "só o admin define liberações, e nunca para o admin" do
      %i[operador consultor laboratorista].each do |papel|
        sign_in users(papel)
        get edit_configuracoes_usuario_liberacoes_path(@pessoa)
        assert_redirected_to root_path, papel
        salvar(instituicoes: [ @centro.id ], setores: [ @ambulatorio.id ], formularios: { @ambulatorio.id => { FORMULARIO => "registra" } })
        assert_empty @pessoa.reload.permissoes.acessos, papel
      end

      sign_in users(:admin)
      get edit_configuracoes_usuario_liberacoes_path(users(:admin))
      assert_redirected_to root_path
    end

    test "a tela mostra a árvore com o que já está liberado" do
      sign_in users(:admin)
      get edit_configuracoes_usuario_liberacoes_path(users(:operador))

      assert_response :success
      assert_select "input[type=checkbox][name='liberacoes[instituicoes][]'][value='#{@centro.id}'][checked]"
      assert_select "input[type=checkbox][name='liberacoes[setores][]'][value='#{@ambulatorio.id}'][checked]"
      assert_select "input[type=checkbox][name='liberacoes[setores][]'][value='#{@laboratorio.id}']:not([checked])"
      assert_select "input[type=radio][name='liberacoes[formularios][#{@ambulatorio.id}][#{FORMULARIO}]'][value='registra'][checked]"

      # Instituição e setores em interruptores; o nome lido inclui o da
      # instituição, porque o título da linha se repete entre instituições
      grupo = "liberacoes_instituicao_#{@centro.id}_titulo"
      assert_select "section[aria-labelledby='#{grupo}'] h2", @centro.nome
      assert_select "input#liberacao_instituicao_#{@centro.id}[role=switch][aria-labelledby='liberacao_instituicao_#{@centro.id}_titulo #{grupo}']"
      assert_select "input#liberacao_setor_#{@ambulatorio.id}[role=switch]"
      # O papel em segmentos: rádios de verdade num radiogroup
      assert_select "[role=radiogroup][aria-labelledby~='liberacao_setor_#{@ambulatorio.id}_titulo']" do
        assert_select "label input[type=radio]", 3
      end
      assert_select "dialog.modal", 0, "as liberações continuam uma página"
    end

    test "liberar os três níveis dá acesso; a auditoria guarda o autor" do
      sign_in users(:admin)
      salvar(instituicoes: [ @centro.id ], setores: [ @ambulatorio.id ], formularios: { @ambulatorio.id => { FORMULARIO => "consulta" } })

      assert_redirected_to configuracoes_usuarios_path
      assert_equal({ [ @ambulatorio.id, FORMULARIO ] => "consulta" }, @pessoa.reload.permissoes.acessos)
      versoes = PaperTrail::Version.where(item_type: %w[LiberacaoInstituicao LiberacaoSetor LiberacaoFormulario])
      assert_equal [ users(:admin).id.to_s ], versoes.where(event: "create").last(3).map(&:whodunnit).uniq
    end

    test "a hierarquia vale mesmo com o formulário adulterado" do
      sign_in users(:admin)
      # Setor sem a instituição marcada, formulário de setor não marcado, papel
      # inventado e formulário inexistente: tudo ignorado
      salvar(instituicoes: [], setores: [ @ambulatorio.id ],
             formularios: { @ambulatorio.id => { FORMULARIO => "registra" }, @laboratorio.id => { FORMULARIO => "registra" } })
      assert_empty @pessoa.reload.liberacoes_setor
      assert_empty @pessoa.liberacoes_formulario

      salvar(instituicoes: [ @centro.id ], setores: [ @ambulatorio.id ],
             formularios: { @ambulatorio.id => { FORMULARIO => "admin", "nao_existe" => "registra" }, @laboratorio.id => { FORMULARIO => "registra" } })
      assert_equal [ @ambulatorio.id ], @pessoa.reload.liberacoes_setor.pluck(:setor_id)
      assert_empty @pessoa.liberacoes_formulario
    end

    test "só formulários habilitados no setor são liberados" do
      formularios_habilitados(:acompanhamento_ambulatorio).delete
      sign_in users(:admin)
      salvar(instituicoes: [ @centro.id ], setores: [ @ambulatorio.id ], formularios: { @ambulatorio.id => { FORMULARIO => "registra" } })

      assert_empty @pessoa.reload.liberacoes_formulario
    end

    test "desmarcar a instituição tira tudo o que está dentro dela" do
      sign_in users(:admin)
      operador = users(:operador)
      salvar(operador, instituicoes: [], setores: [ @ambulatorio.id ], formularios: { @ambulatorio.id => { FORMULARIO => "registra" } })

      assert_empty operador.reload.liberacoes_instituicao
      assert_empty operador.liberacoes_setor
      assert_empty operador.liberacoes_formulario
    end

    test "trocar o papel e tirar o formulário" do
      sign_in users(:admin)
      operador = users(:operador)

      salvar(operador, instituicoes: [ @centro.id ], setores: [ @ambulatorio.id ], formularios: { @ambulatorio.id => { FORMULARIO => "consulta" } })
      assert_equal "consulta", operador.reload.permissoes.papel(@ambulatorio.id, FORMULARIO)

      salvar(operador, instituicoes: [ @centro.id ], setores: [ @ambulatorio.id ], formularios: { @ambulatorio.id => { FORMULARIO => "" } })
      assert_nil operador.reload.permissoes.papel(@ambulatorio.id, FORMULARIO)
      assert operador.liberacoes_setor.exists?(setor: @ambulatorio), "o setor continua liberado"
    end

    private

    def salvar(usuario = @pessoa, instituicoes:, setores:, formularios:)
      patch configuracoes_usuario_liberacoes_path(usuario), params: {
        liberacoes: { instituicoes: [ "" ] + instituicoes, setores:, formularios: }
      }
    end
  end
end
