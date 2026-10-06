# Base das telas de Configurações: tudo só para o admin. Operador e consultor
# não veem o menu e, se tentarem pela URL, recebem "Você não tem permissão".
# (O consultor já é barrado em qualquer escrita pelo ApplicationController.)
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
