# Liberação de uma pessoa num formulário de um setor, com o papel: "registra"
# (registra, atualiza e consulta) ou "consulta" (só consulta). O terceiro dos
# três níveis (ver Permissoes): só vale com as liberações da instituição e do
# setor, e com o formulário habilitado no setor.
class LiberacaoFormulario < ApplicationRecord
  self.table_name = "liberacoes_formulario"
  PAPEIS = %w[registra consulta].freeze

  belongs_to :user, inverse_of: :liberacoes_formulario
  belongs_to :setor
  has_paper_trail

  validates :papel, inclusion: { in: PAPEIS }
  validates :formulario, uniqueness: { scope: %i[user_id setor_id] }
  validate :formulario_habilitado_no_setor

  private

  def formulario_habilitado_no_setor
    return if setor && FormularioHabilitado.exists?(setor:, formulario:)

    errors.add(:formulario, "não está habilitado neste setor")
  end
end
