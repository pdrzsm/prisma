# Um setor de uma instituição (ex.: um ambulatório ou uma unidade). Cadastrado
# pelo admin em Configurações, dentro da instituição.
class Setor < ApplicationRecord
  belongs_to :instituicao, inverse_of: :setores
  has_paper_trail

  normalizes :nome, with: ->(nome) { nome.squish }

  # O mesmo nome pode se repetir em outra instituição, nunca na mesma
  validates :nome, presence: true, length: { maximum: 150 },
                   uniqueness: { scope: :instituicao_id, case_sensitive: false }
end
