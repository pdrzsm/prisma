# Login com limite de tentativas por IP (contra testes em massa de senhas).
# O bloqueio por conta é do :lockable, em config/initializers/devise.rb.
class Users::SessionsController < Devise::SessionsController
  rate_limit to: 20, within: 3.minutes, only: :create,
             with: -> { redirect_to new_user_session_path, alert: "Muitas tentativas de login. Aguarde alguns minutos.", status: :see_other }
end
