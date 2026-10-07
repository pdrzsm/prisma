# Um formulário (YAML de config/formularios) habilitado num setor pelo admin.
# Só nos setores em que está habilitado o formulário pode ser liberado para
# alguém e receber notificações.
class FormularioHabilitado < ApplicationRecord
  belongs_to :setor, inverse_of: :formularios_habilitados
  has_paper_trail

  validates :formulario, inclusion: { in: ->(_) { Formulario.chaves } },
                         uniqueness: { scope: :setor_id }

  # Registro clínico é preservado: um formulário com notificações no setor não
  # sai do setor, ou elas ficariam sem quem as veja
  before_destroy :manter_se_tem_notificacoes

  private

  def manter_se_tem_notificacoes
    return unless AvaliacaoClinica.exists?(setor_id:, formulario:)

    errors.add(:base, "#{Formulario.find(formulario).titulo} tem notificações neste setor e não pode ser desabilitado")
    throw :abort
  end
end
