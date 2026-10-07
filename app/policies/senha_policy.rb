# Policy sem model (headless): `authorize :senha` na troca da própria senha.
# Qualquer pessoa autenticada troca a sua (e só a sua: o controller usa
# sempre o current_user).
class SenhaPolicy < ApplicationPolicy
  def update?
    true
  end
end
