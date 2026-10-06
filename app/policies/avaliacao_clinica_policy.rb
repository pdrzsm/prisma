class AvaliacaoClinicaPolicy < ApplicationPolicy
  # Listas explícitas em vez de `true`: um papel novo começa sem acesso
  LEITURA = %w[operador consultor admin].freeze
  ESCRITA = %w[operador admin].freeze

  def index?
    LEITURA.include?(user.role)
  end

  def show?
    index?
  end

  def create?
    ESCRITA.include?(user.role)
  end

  # O seguimento é atualizado ao longo do tratamento; cada alteração fica na
  # auditoria (PaperTrail). edit? segue update? (ApplicationPolicy).
  def update?
    ESCRITA.include?(user.role)
  end

  # destroy? continua negado (herdado): registro clínico não é apagado

  class Scope < ApplicationPolicy::Scope
    def resolve
      LEITURA.include?(user.role) ? scope.all : scope.none
    end
  end
end
