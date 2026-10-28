# Policy sem model (headless): usada com `authorize :relatorios`.
class RelatoriosPolicy < ApplicationPolicy
  # Qualquer usuário autenticado entra; os números vêm só das notificações que
  # as liberações dele permitem (AvaliacaoClinicaPolicy::Scope)
  def index?
    true
  end
end
