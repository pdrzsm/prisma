# Uma instituição (ex.: um hospital ou centro de referência), o nível mais alto
# da organização do Prisma. Cada uma tem os seus setores. Só o admin cadastra,
# em Configurações (Configuracoes::InstituicoesController).
#
# Próxima fase (docs/arquitetura.md): pessoas, formulários e pacientes passam a
# pertencer a um setor, com liberação explícita em cada nível.
class Instituicao < ApplicationRecord
  # Instituição com setores não é excluída: primeiro saem os setores
  has_many :setores, -> { order(:nome) }, dependent: :restrict_with_error, inverse_of: :instituicao
  has_paper_trail

  # Sem espaços sobrando; sigla em maiúsculas e em branco vira nil
  normalizes :nome, with: ->(nome) { nome.squish }
  normalizes :sigla, with: ->(sigla) { sigla.squish.upcase.presence }

  validates :nome, presence: true, length: { maximum: 150 }, uniqueness: { case_sensitive: false }
  validates :sigla, length: { maximum: 20 }, uniqueness: { case_sensitive: false }, allow_nil: true
end
