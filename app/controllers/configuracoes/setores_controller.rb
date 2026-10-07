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

      if @setor.save && @setor.habilitar_formularios(formularios_param)
        redirect_to volta_para_instituicao, notice: "Setor cadastrado."
      else
        flash.now[:alert] = mensagem_de_erro
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @setor.update(setor_params) && @setor.habilitar_formularios(formularios_param)
        redirect_to volta_para_instituicao, notice: "Setor atualizado."
      else
        flash.now[:alert] = mensagem_de_erro
        render :edit, status: :unprocessable_content
      end
    end

    # Setor com pacientes não sai (registro clínico é preservado)
    def destroy
      if @setor.destroy
        redirect_to volta_para_instituicao, notice: "Setor excluído.", status: :see_other
      else
        redirect_to edit_configuracoes_instituicao_setor_path(@instituicao, @setor),
                    alert: @setor.errors.full_messages.to_sentence, status: :see_other
      end
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

    # Chaves dos formulários marcados; a lista vazia (tudo desmarcado) chega
    # pelo campo escondido do formulário
    def formularios_param
      Array(params.dig(:setor, :formularios)).compact_blank
    end

    # O erro que não é de um campo (ex.: formulário com notificações que não
    # pode ser desabilitado) vai no aviso; senão, o aviso aponta os campos
    def mensagem_de_erro
      @setor.errors[:base].to_sentence.presence || "Não foi possível salvar. Revise os campos destacados."
    end

    # A lista, já rolada até o cartão da instituição
    def volta_para_instituicao
      configuracoes_instituicoes_path(anchor: helpers.dom_id(@instituicao))
    end
  end
end
