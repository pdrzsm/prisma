# Publicação do rascunho de um formulário. A tela de revisão mostra o que muda
# em relação à versão publicada, o que ainda impede a publicação e os avisos
# de minimização (LGPD, art. 6º, III). Para publicar, o admin confirma que a
# finalidade e a base legal foram validadas com o encarregado (DPO) e que
# cada pergunta é necessária. Publicada, a versão nunca mais muda; as
# notificações novas passam a usá-la, e as antigas continuam com a delas.
module Configuracoes
  class PublicacoesController < GeradorController
    CONFIRMACOES = %w[confirma_dpo confirma_minimizacao].freeze

    before_action :carregar_rascunho
    before_action :preparar_revisao

    def new
    end

    def create
      authorize [ :configuracoes, @formulario ], :publicar?
      confirmacoes = params.fetch(:publicacao, {}).permit(*CONFIRMACOES)
      unless CONFIRMACOES.all? { |campo| confirmacoes[campo] == "1" }
        flash.now[:alert] = "Para publicar, confirme os dois itens da revisão."
        return render :new, status: :unprocessable_content
      end

      # Publica exatamente o que foi revisto: se o rascunho mudou depois, recusa
      revisto = Integer(params[:lock_version].to_s, 10, exception: false)
      return rascunho_mudou unless revisto

      @rascunho.lock_version = revisto
      @rascunho.publicar!(por: current_user)
      redirect_to configuracoes_formulario_path(@formulario),
                  notice: "Versão #{@rascunho.numero} publicada. As notificações novas já usam esta versão; as antigas continuam com a delas."
    rescue ActiveRecord::RecordInvalid
      @rascunho.reload
      preparar_revisao
      render :new, status: :unprocessable_content
    end

    private

    # O que impede a publicação vem da mesma conferência que a publicação faz
    def preparar_revisao
      @definicao = @rascunho.definicao
      @impedimentos = begin
        DefinicaoDeFormulario.new(@rascunho.estrutura)
        []
      rescue DefinicaoDeFormulario::DefinicaoInvalida => e
        e.erros.map(&:mensagem)
      end
      @comparacao = ComparacaoDeVersoes.new(@formulario.definicao, @definicao)
      @avisos = AvisosDeMinimizacao.para(@definicao)
      @texto_livre = AvisosDeMinimizacao.tem_texto_livre?(@definicao)
    end
  end
end
