# As seções do rascunho de um formulário (Configurações > Gerador de
# formulários): criar, renomear, mover e remover. Só seção vazia é removida.
module Configuracoes
  class SecoesController < GeradorController
    before_action :carregar_rascunho
    before_action :carregar_secao, only: [ :edit, :update, :destroy, :mover ]

    def new
      @secao = {}
    end

    def create
      @secao = secao_params
      if edicao.adicionar_secao(titulo: @secao[:titulo], descricao: @secao[:descricao])
        redirect_to no_rascunho(@rascunho.definicao.secoes.last.id), notice: "Seção criada."
      else
        guardar_erros_e_recarregar
        render :new, status: :unprocessable_content
      end
    end

    def edit
      @secao = { titulo: @secao_atual.titulo, descricao: @secao_atual.descricao }
    end

    def update
      @secao = secao_params
      if edicao.atualizar_secao(@secao_atual.id, titulo: @secao[:titulo], descricao: @secao[:descricao])
        redirect_to no_rascunho(@secao_atual.id), notice: "Seção salva."
      else
        guardar_erros_e_recarregar
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if edicao.remover_secao(@secao_atual.id)
        redirect_to no_rascunho, notice: "Seção removida.", status: :see_other
      else
        redirect_to edit_configuracoes_formulario_rascunho_secao_path(@formulario, @secao_atual.id),
                    alert: @rascunho.errors.full_messages.to_sentence, status: :see_other
      end
    end

    def mover
      if edicao.mover_secao(@secao_atual.id, params[:direcao])
        redirect_to no_rascunho(@secao_atual.id), status: :see_other
      else
        redirect_to no_rascunho(@secao_atual.id), alert: @rascunho.errors.full_messages.to_sentence, status: :see_other
      end
    end

    private

    def carregar_secao
      @secao_atual = definicao.secoes.find { |secao| secao.id == params[:id] } or raise ActiveRecord::RecordNotFound
    end

    def secao_params
      params.expect(secao: [ :titulo, :descricao ]).to_h.symbolize_keys
    end
  end
end
