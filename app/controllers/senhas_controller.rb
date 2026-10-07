# Troca da própria senha. É obrigatória no primeiro acesso e depois que o
# admin redefine a senha (deve_trocar_senha): nesses casos, é a única tela que
# abre (ver ApplicationController#exigir_troca_de_senha). Sempre a senha do
# current_user: não há como trocar a de outra pessoa por aqui.
class SenhasController < ApplicationController
  def edit
    authorize :senha
  end

  def update
    authorize :senha
    nova = senha_params[:password].to_s

    # Sem estas checagens, o Devise aceitaria "nova senha" em branco (e só
    # apagaria a obrigação de trocar) ou a mesma senha de antes
    if nova.blank?
      current_user.errors.add(:password, :blank)
    elsif current_user.valid_password?(nova)
      current_user.errors.add(:password, "precisa ser diferente da senha atual")
    elsif current_user.update_with_password(senha_params.merge(deve_trocar_senha: false))
      # Trocar a senha invalida as sessões abertas; esta continua
      bypass_sign_in(current_user)
      return redirect_to root_path, notice: "Senha alterada."
    end

    flash.now[:alert] = "Não foi possível trocar a senha. Revise os campos destacados."
    render :edit, status: :unprocessable_content
  end

  private

  def senha_params
    params.expect(usuario: [ :current_password, :password, :password_confirmation ])
  end
end
