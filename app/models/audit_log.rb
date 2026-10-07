# Uma leitura de dado sensível: quem viu qual registro, quando, de qual IP e
# com qual navegador (LGPD, art. 37 e 46). Gravada por
# ApplicationController#log_read_access antes de a página ser montada.
#
# Imutável: só se cria. Alterar ou apagar levanta ActiveRecord::ReadOnlyRecord.
# Isso protege contra erro no código; contra quem tem acesso ao banco, a
# proteção é o usuário de produção não ter UPDATE nem DELETE nesta tabela
# (docs/seguranca.md).
class AuditLog < ApplicationRecord
  # As actions que exibem dado sensível. "update" é a edição que não foi salva
  # (resposta inválida ou conflito): a tela de edição volta com os dados.
  ACOES = %w[index show edit update].freeze

  belongs_to :user
  belongs_to :auditable, polymorphic: true

  validates :action, inclusion: { in: ACOES }

  # Leituras de um registro, da mais recente para a mais antiga
  scope :do_registro, ->(registro) { where(auditable: registro).order(created_at: :desc, id: :desc) }
  # Leituras de qualquer notificação de um paciente (pedido de um titular)
  scope :do_paciente, lambda { |paciente|
    where(auditable_type: AvaliacaoClinica.polymorphic_name, auditable_id: paciente.avaliacoes_clinicas.select(:id))
      .order(created_at: :desc, id: :desc)
  }

  # Depois de gravado, nada muda: save, update e destroy levantam ReadOnlyRecord
  def readonly?
    persisted? || super
  end
end
