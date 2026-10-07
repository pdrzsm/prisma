# Liberação de uma pessoa num setor: o segundo dos três níveis (ver
# Permissoes). Só vale com a liberação da instituição do setor.
class LiberacaoSetor < ApplicationRecord
  self.table_name = "liberacoes_setor"

  belongs_to :user, inverse_of: :liberacoes_setor
  belongs_to :setor
  has_paper_trail

  validates :setor_id, uniqueness: { scope: :user_id }
end
