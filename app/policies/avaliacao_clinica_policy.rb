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

  # update? e destroy? continuam negados (herdados): avaliação registrada não é
  # alterada nem apagada, para preservar o histórico clínico

  class Scope < ApplicationPolicy::Scope
    def resolve
      LEITURA.include?(user.role) ? scope.all : scope.none
    end
  end
end
