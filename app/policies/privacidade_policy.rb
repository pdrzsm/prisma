# Policy sem model (headless): `authorize :privacidade`. Toda pessoa
# autenticada pode ler como os dados são tratados.
class PrivacidadePolicy < ApplicationPolicy
  def show?
    true
  end
end
