class ApplicationController < ActionController::Base
  include Pundit::Authorization

  allow_browser versions: :modern

  # Toda rota exige login por padrão. O Devise ignora este filtro nos próprios
  # controllers (sessions etc.), então a tela de login continua acessível.
  # Páginas públicas devem usar `skip_before_action :authenticate_user!` explicitamente.
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  # Senha temporária (conta nova ou senha redefinida pelo admin): nenhuma tela
  # abre antes da troca. Fora do Devise para o logout continuar funcionando.
  before_action :exigir_troca_de_senha, unless: :devise_controller?
  # Páginas com dados de saúde não ficam no cache do navegador: o "voltar"
  # depois do logout não mostra nada num computador compartilhado
  before_action :no_store
  # Autor das alterações na trilha de auditoria (PaperTrail)
  before_action :set_paper_trail_whodunnit

  # Falha a requisição se a action esquecer `authorize` (ou `policy_scope` no index).
  # Roda DEPOIS da action, então não substitui chamar `authorize` antes de gravar.
  # Equivale a `verify_authorized, except: :index` + `verify_policy_scoped, only: :index`,
  # mas sem only/except, que com raise_on_missing_callback_actions quebram todo
  # controller sem action index (inclusive os do Devise).
  after_action :verify_pundit_authorization, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :login ])
  end

  private

  def exigir_troca_de_senha
    return unless current_user&.deve_trocar_senha?
    return if controller_path == "senhas"

    redirect_to edit_senha_path, alert: "Antes de continuar, troque a senha temporária por uma só sua."
  end

  def verify_pundit_authorization
    if action_name == "index"
      verify_policy_scoped
    else
      verify_authorized
    end
  end

  def user_not_authorized
    redirect_back_or_to root_path, alert: "Você não tem permissão para realizar esta ação.", status: :see_other
  end
end
