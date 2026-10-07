# Policy sem model (headless): usada com `authorize :formulario` na aba
# Formulários. A lista de formulários disponíveis não tem dado de paciente.
class FormularioPolicy < ApplicationPolicy
  def index?
    true
  end
end
