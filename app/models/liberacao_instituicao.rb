# Liberação de uma pessoa numa instituição: o primeiro dos três níveis (ver
# Permissoes). Sem ela, nenhuma liberação de setor ou formulário dessa
# instituição vale.
class LiberacaoInstituicao < ApplicationRecord
  self.table_name = "liberacoes_instituicao"

  belongs_to :user, inverse_of: :liberacoes_instituicao
  belongs_to :instituicao
  has_paper_trail

  validates :instituicao_id, uniqueness: { scope: :user_id }
end
