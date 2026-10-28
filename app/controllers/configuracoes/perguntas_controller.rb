# As perguntas do rascunho de um formulário (Configurações > Gerador de
# formulários): criar (numa seção, ou dependendo de uma pergunta de escolha:
# "se escolher isso, aparece aquilo"), alterar, mover e remover. A pergunta é
# identificada pela chave, que o sistema gera e nunca muda.
#
# A tela é lida por PerguntaDoGerador; a mudança, gravada por
# EdicaoDoRascunho, que confere a definição inteira antes de gravar.
module Configuracoes
  class PerguntasController < GeradorController
    CAMPOS = (PerguntaDoGerador::CAMPOS + [ { valores: [] } ]).freeze

    before_action :carregar_rascunho
    before_action :carregar_pergunta, only: [ :edit, :update, :remover, :destroy, :mover ]
    before_action :carregar_lugar, only: [ :new, :create ]

    def new
      tipo = params[:tipo].presence_in(DefinicaoDeFormulario::TIPOS.keys) || "texto"
      @pergunta = PerguntaDoGerador.new(tipo:, numeracao_manual: numeracao_manual?, controladora: @controladora)
    end

    def create
      @pergunta = PerguntaDoGerador.new(pergunta_params.merge(numeracao_manual: numeracao_manual?, controladora: @controladora))
      chave = @pergunta.valid? &&
              edicao.adicionar_pergunta(secao_id: @secao.id, atributos: @pergunta.atributos, controladora: @controladora&.chave,
                                        valores: @pergunta.valores)
      return redirect_to(no_rascunho("pergunta-#{chave}"), notice: "Pergunta criada.") if chave

      voltar_com_erros :new
    end

    def edit
      @pergunta = PerguntaDoGerador.de(@pergunta_atual, numeracao_manual: numeracao_manual?, controladora: @controladora)
    end

    def update
      @pergunta = PerguntaDoGerador.new(pergunta_params.merge(numeracao_manual: numeracao_manual?, controladora: @controladora))
      if @pergunta.valid? && edicao.atualizar_pergunta(@pergunta_atual.chave, @pergunta.atributos, valores: @pergunta.valores)
        return redirect_to(no_rascunho("pergunta-#{@pergunta_atual.chave}"), notice: "Pergunta salva.")
      end

      voltar_com_erros :edit
    end

    # Confirmação antes de remover: mostra também as que dependem dela
    def remover
      @removidas = [ @pergunta_atual ] + descendentes(@pergunta_atual)
    end

    def destroy
      if edicao.remover_pergunta(@pergunta_atual.chave)
        redirect_to no_rascunho(@pergunta_atual.secao_id), notice: "Pergunta removida.", status: :see_other
      else
        redirect_to remover_configuracoes_formulario_rascunho_pergunta_path(@formulario, @pergunta_atual.chave),
                    alert: @rascunho.errors.full_messages.to_sentence, status: :see_other
      end
    end

    def mover
      alerta = @rascunho.errors.full_messages.to_sentence unless edicao.mover_pergunta(@pergunta_atual.chave, params[:direcao])
      redirect_to no_rascunho("pergunta-#{@pergunta_atual.chave}"), alert: alerta, status: :see_other
    end

    private

    def carregar_pergunta
      @pergunta_atual = definicao.pergunta(params[:id]) or raise ActiveRecord::RecordNotFound
      @controladora = definicao.controladora(@pergunta_atual)
      @secao = definicao.secoes.find { |secao| secao.id == @pergunta_atual.secao_id }
    end

    # Onde entra a pergunta nova: numa seção ou, com controladora, logo abaixo
    # de uma pergunta de escolha (na seção dela). Fora disso, 404
    def carregar_lugar
      if params[:controladora].present?
        @controladora = definicao.pergunta(params[:controladora])
        raise ActiveRecord::RecordNotFound unless @controladora&.escolha?

        @secao_id = @controladora.secao_id
      else
        @secao_id = params[:secao]
      end
      @secao = definicao.secoes.find { |secao| secao.id == @secao_id } or raise ActiveRecord::RecordNotFound
    end

    def pergunta_params
      params.expect(pergunta: CAMPOS).to_h.symbolize_keys.slice(*PerguntaDoGerador::CAMPOS, :valores)
    end

    def descendentes(pergunta)
      definicao.dependentes(pergunta).flat_map { |dependente| [ dependente ] + descendentes(dependente) }
    end

    # Os erros da tela e os da definição inteira (que só aparecem ao gravar)
    def voltar_com_erros(tela)
      guardar_erros_e_recarregar
      @erros.each { |erro| @pergunta.errors.add(:base, erro) }
      render tela, status: :unprocessable_content
    end
  end
end
