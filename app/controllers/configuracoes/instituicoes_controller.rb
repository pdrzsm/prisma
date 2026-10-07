# Configurações > Instituições e setores, só para o admin (InstituicaoPolicy).
# A lista mostra cada instituição com os seus setores; os setores têm o
# próprio controller (Configuracoes::SetoresController).
module Configuracoes
  class InstituicoesController < ApplicationController
    before_action :carregar_instituicao, only: [ :edit, :update, :destroy ]

    def index
      authorize Instituicao
      @instituicoes = policy_scope(Instituicao).includes(:setores).order(:nome)
    end

    def new
      authorize Instituicao
      @instituicao = Instituicao.new
    end

    def create
      authorize Instituicao
      @instituicao = Instituicao.new(instituicao_params)

      if @instituicao.save
        redirect_to configuracoes_instituicoes_path(anchor: helpers.dom_id(@instituicao)), notice: "Instituição cadastrada."
      else
        flash.now[:alert] = "Não foi possível salvar. Revise os campos destacados."
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @instituicao.update(instituicao_params)
        redirect_to configuracoes_instituicoes_path(anchor: helpers.dom_id(@instituicao)), notice: "Instituição atualizada."
      else
        flash.now[:alert] = "Não foi possível salvar. Revise os campos destacados."
        render :edit, status: :unprocessable_content
      end
    end

    # Só sai sem setores (restrict_with_error no model); fica na auditoria
    def destroy
      if @instituicao.destroy
        redirect_to configuracoes_instituicoes_path, notice: "Instituição excluída.", status: :see_other
      else
        redirect_to edit_configuracoes_instituicao_path(@instituicao),
                    alert: @instituicao.errors.full_messages.to_sentence, status: :see_other
      end
    end

    private

    def carregar_instituicao
      @instituicao = Instituicao.find(params[:id])
      authorize @instituicao
    end

    def instituicao_params
      params.expect(instituicao: [ :nome, :sigla ])
    end
  end
end
