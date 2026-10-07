# Base das telas de Configurações: tudo só para o admin (a conta única). Os
# outros usuários não veem o menu e, se tentarem pela URL, recebem "Você não
# tem permissão".
class ConfiguracaoPolicy < ApplicationPolicy
  def index? = admin?
  def create? = admin?
  def update? = admin?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.admin? ? scope.all : scope.none
    end
  end

  private

  def admin? = user.admin?
end
