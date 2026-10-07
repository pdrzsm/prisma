# O que um usuário pode acessar: instituições, setores e, em cada setor, os
# formulários com o papel (registra ou só consulta). Só o admin (UserPolicy),
# e só para usuários comuns. A tela manda o estado inteiro e
# LiberacoesDoUsuario acerta o banco, mantendo a hierarquia.
module Configuracoes
  class LiberacoesController < ApplicationController
    before_action :carregar_usuario

    def edit
      @instituicoes = Instituicao.includes(setores: :formularios_habilitados).order(:nome)
      @liberadas = {
        instituicoes: @usuario.liberacoes_instituicao.pluck(:instituicao_id).to_set,
        setores: @usuario.liberacoes_setor.pluck(:setor_id).to_set,
        formularios: @usuario.liberacoes_formulario.to_h { |liberacao| [ [ liberacao.setor_id, liberacao.formulario ], liberacao.papel ] }
      }
    end

    def update
      liberacoes = params.fetch(:liberacoes, {}).permit(instituicoes: [], setores: [], formularios: {})
      LiberacoesDoUsuario.new(@usuario).atualizar(
        instituicoes: liberacoes[:instituicoes],
        setores: liberacoes[:setores],
        formularios: liberacoes[:formularios].to_h
      )
      redirect_to configuracoes_usuarios_path, notice: "Liberações de #{@usuario.nome} salvas."
    end

    private

    def carregar_usuario
      @usuario = User.find(params[:usuario_id])
      authorize @usuario, :liberar?
    end
  end
end
