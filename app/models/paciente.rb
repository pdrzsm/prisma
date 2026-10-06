class Paciente < ApplicationRecord
  class IdentificadoresConflitantes < StandardError; end

  # O prontuário precisa ser preservado (Lei 13.787/2018): paciente com
  # avaliações não pode ser apagado, e nada é apagado em cascata
  has_many :avaliacoes_clinicas, dependent: :restrict_with_error
  has_paper_trail

  # Identificadores: determinístico permite busca exata (find_by) no banco
  encrypts :cpf, :prontuario_sah, :prontuario_aghuse, :numero_sinan, deterministic: true
  encrypts :nome, :numero_contatos

  normalizes :cpf, with: ->(cpf) { Cpf.normalizar(cpf) }
  normalizes :nome, :prontuario_sah, :prontuario_aghuse, :numero_sinan, :municipio_residencia, :numero_contatos,
             with: ->(valor) { valor.squish.presence }

  # Os limites garantem que o texto cifrado caiba nas colunas
  validates :nome, presence: true, length: { maximum: 150 }
  validates :cpf, cpf: true, uniqueness: true, allow_nil: true
  validates :prontuario_sah, :prontuario_aghuse, :numero_sinan, length: { maximum: 30 }
  validates :municipio_residencia, length: { maximum: 100 }
  validates :numero_contatos, length: { maximum: 120 }

  # Localiza o paciente pelo CPF ou, sem CPF, pelo prontuário SAH, sem alterar
  # o cadastro encontrado. Se os dois identificadores apontarem para pacientes
  # diferentes, levanta IdentificadoresConflitantes em vez de escolher um.
  def self.identificar(cpf:, prontuario_sah:)
    cpf = normalize_value_for(:cpf, cpf)
    prontuario_sah = normalize_value_for(:prontuario_sah, prontuario_sah)

    por_cpf = find_by(cpf:) if cpf
    por_prontuario = find_by(prontuario_sah:) if prontuario_sah
    raise IdentificadoresConflitantes if por_cpf && por_prontuario && por_cpf != por_prontuario

    por_cpf || por_prontuario
  end
end
