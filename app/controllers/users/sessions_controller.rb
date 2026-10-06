# Login com limite de tentativas por IP (contra testes em massa de senhas).
# O bloqueio por conta é do :lockable, em config/initializers/devise.rb.
class Users::SessionsController < Devise::SessionsController
  rate_limit to: 20, within: 3.minutes, only: :create,
             with: -> { redirect_to new_user_session_path, alert: "Muitas tentativas de login. Aguarde alguns minutos.", status: :see_other }

  private

  # Depois de sair, direto para o login. A raiz exige login e trocaria o aviso
  # "Você saiu do sistema." por "Para continuar, entre no sistema."
  def after_sign_out_path_for(_escopo)
    new_user_session_path
  end
end
