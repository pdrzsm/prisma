# Uma instituição (ou unidade, ex.: um hospital ou centro de referência), o
# nível mais alto da organização do Prisma. Cada uma tem os seus setores. Só o
# admin cadastra, em Configurações (Configuracoes::InstituicoesController), e
# libera pessoas nela (LiberacaoInstituicao, o primeiro nível de Permissoes).
class Instituicao < ApplicationRecord
  # Instituição com setores não é excluída: primeiro saem os setores
  has_many :setores, -> { order(:nome) }, dependent: :restrict_with_error, inverse_of: :instituicao
  has_many :liberacoes_instituicao, class_name: "LiberacaoInstituicao", dependent: :destroy
  has_paper_trail

  # Sem espaços sobrando; sigla em maiúsculas e em branco vira nil
  normalizes :nome, with: ->(nome) { nome.squish }
  normalizes :sigla, with: ->(sigla) { sigla.squish.upcase.presence }

  validates :nome, presence: true, length: { maximum: 150 }, uniqueness: { case_sensitive: false }
  validates :sigla, length: { maximum: 20 }, uniqueness: { case_sensitive: false }, allow_nil: true
end
