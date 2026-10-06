# Policy sem model (headless): usada com `authorize :dashboard`.
class DashboardPolicy < ApplicationPolicy
  # Tela inicial liberada para qualquer usuário autenticado; o
  # ApplicationPolicy já rejeita user nil.
  def index?
    true
  end
end
