# Policy sem model (headless): `authorize :tema` na escolha do modo claro ou
# noturno. Qualquer pessoa autenticada escolhe o seu (fica num cookie do navegador).
class TemaPolicy < ApplicationPolicy
  def update?
    true
  end
end
