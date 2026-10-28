# O admin define uma senha temporária para um usuário (esqueceu a senha, conta
# bloqueada...). A pessoa é obrigada a trocá-la no próximo acesso, e as
# sessões abertas dela caem, porque a senha mudou. Não vale para o admin, que
# troca a própria senha pela tela de senha. Abre num modal por cima da lista
# de usuários (ModalHelper).
module Configuracoes
  class SenhasTemporariasController < ApplicationController
    before_action :carregar_usuario

    def edit
      carregar_lista
    end

    def update
      senha = params.expect(usuario: [ :password, :password_confirmation ])

      if senha[:password].blank?
        @usuario.errors.add(:password, :blank)
      elsif @usuario.update(senha.merge(deve_trocar_senha: true))
        @usuario.unlock_access! if @usuario.access_locked?
        return redirect_to edit_configuracoes_usuario_path(@usuario),
                           notice: "Senha temporária definida. No próximo acesso, #{@usuario.nome} vai ter de trocá-la."
      end

      flash.now[:alert] = "Não foi possível salvar. Revise os campos destacados."
      carregar_lista
      render :edit, status: :unprocessable_content
    end

    private

    # A lista de usuários, ao fundo do modal (a mesma de UsuariosController)
    def carregar_lista
      @usuarios = policy_scope(User).includes(:liberacoes_formulario)
                                    .order(Arel.sql("role = 'admin' DESC"), :nome)
    end

    def carregar_usuario
      @usuario = User.find(params[:usuario_id])
      authorize @usuario, :redefinir_senha?
    end
  end
end
