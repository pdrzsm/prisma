# Setores de uma instituição, só para o admin (SetorPolicy). Ficam dentro da
# instituição na URL (/configuracoes/instituicoes/1/setores/2/edit) e sempre
# são buscados por ela: um id de setor de outra instituição dá 404.
module Configuracoes
  class SetoresController < ApplicationController
    before_action :carregar_instituicao
    before_action :carregar_setor, only: [ :edit, :update, :destroy ]

    def new
      @setor = @instituicao.setores.build
      authorize @setor
    end

    def create
      @setor = @instituicao.setores.build(setor_params)
      authorize @setor

      if @setor.save
        redirect_to volta_para_instituicao, notice: "Setor cadastrado."
      else
        flash.now[:alert] = "Não foi possível salvar. Revise os campos destacados."
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @setor.update(setor_params)
        redirect_to volta_para_instituicao, notice: "Setor atualizado."
      else
        flash.now[:alert] = "Não foi possível salvar. Revise os campos destacados."
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @setor.destroy!
      redirect_to volta_para_instituicao, notice: "Setor excluído.", status: :see_other
    end

    private

    def carregar_instituicao
      @instituicao = Instituicao.find(params[:instituicao_id])
    end

    def carregar_setor
      @setor = @instituicao.setores.find(params[:id])
      authorize @setor
    end

    def setor_params
      params.expect(setor: [ :nome ])
    end

    # A lista, já rolada até o cartão da instituição
    def volta_para_instituicao
      configuracoes_instituicoes_path(anchor: helpers.dom_id(@instituicao))
    end
  end
end
