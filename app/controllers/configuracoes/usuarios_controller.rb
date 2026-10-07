# Configurações > Usuários, só para o admin (UserPolicy). A conta nova sempre
# é de usuário comum (o admin é único e nunca é criado pela tela), com senha
# temporária que a pessoa troca no primeiro acesso. Ninguém é excluído:
# desativar tira o acesso e derruba a sessão aberta.
module Configuracoes
  class UsuariosController < ApplicationController
    before_action :carregar_usuario, only: [ :edit, :update ]

    def index
      authorize User
      # O admin primeiro; depois por nome
      @usuarios = policy_scope(User).includes(:liberacoes_formulario)
                                    .order(Arel.sql("role = 'admin' DESC"), :nome)
    end

    def new
      authorize User
      @usuario = User.new
    end

    def create
      authorize User
      @usuario = User.new(params.expect(usuario: [ :nome, :username, :cpf, :password, :password_confirmation ]))
      @usuario.role = "usuario"
      @usuario.deve_trocar_senha = true

      if @usuario.save
        redirect_to edit_configuracoes_usuario_liberacoes_path(@usuario),
                    notice: "Usuário cadastrado. Agora defina o que ele pode acessar."
      else
        flash.now[:alert] = "Não foi possível salvar. Revise os campos destacados."
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @usuario.update(usuario_params)
        redirect_to configuracoes_usuarios_path, notice: "Usuário atualizado."
      else
        flash.now[:alert] = "Não foi possível salvar. Revise os campos destacados."
        render :edit, status: :unprocessable_content
      end
    end

    private

    def carregar_usuario
      @usuario = User.find(params[:id])
      authorize @usuario
    end

    # O papel nunca vem do formulário; a conta admin não se desativa
    def usuario_params
      campos = %i[nome username cpf]
      campos << :ativo if @usuario.usuario?
      params.expect(usuario: campos)
    end
  end
end
