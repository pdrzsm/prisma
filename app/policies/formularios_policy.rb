# Policy sem model (headless): usada com `authorize :formularios`.
class FormulariosPolicy < ApplicationPolicy
  # A página só lista o que a pessoa já pode consultar; qualquer usuário
  # autenticado entra (sem liberação, ela vê o aviso).
  def index?
    true
  end
end
