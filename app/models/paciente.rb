class Paciente < ApplicationRecord
  class IdentificacaoInvalida < StandardError; end

  # O prontuário precisa ser preservado (Lei 13.787/2018): paciente com
  # avaliações não pode ser apagado, e nada é apagado em cascata
  has_many :avaliacoes_clinicas, dependent: :restrict_with_error
  has_paper_trail

  # Identificação mínima, como no formulário: prontuários e iniciais, sem nome
  # completo nem CPF. Prontuários em modo determinístico para a busca exata.
  encrypts :prontuario_sah, :prontuario_aghuse, deterministic: true
  encrypts :iniciais

  # Sem espaços e em maiúsculas: "sah 001" e "SAH001" são o mesmo prontuário,
  # e não viram dois pacientes. A pontuação é mantida.
  normalizes :prontuario_sah, :prontuario_aghuse, with: ->(prontuario) { prontuario.gsub(/\s+/, "").upcase.presence }
  normalizes :iniciais, with: ->(iniciais) { iniciais.gsub(/[^\p{L}]/, "").upcase.presence }

  validates :iniciais, presence: true, length: { maximum: 10 }
  validates :prontuario_sah, :prontuario_aghuse, length: { maximum: 30 }, uniqueness: true, allow_nil: true

  scope :com_prontuario, ->(prontuario) { where(prontuario_sah: prontuario).or(where(prontuario_aghuse: prontuario)) }

  # Localiza o paciente pelos prontuários, sem alterar o cadastro encontrado.
  # Recusa (IdentificacaoInvalida) quando os dados informados não batem com o
  # cadastro: assim uma notificação não vai parar no paciente errado por causa
  # de um prontuário digitado errado.
  def self.identificar(prontuario_sah:, prontuario_aghuse:, iniciais:)
    informados = {
      prontuario_sah: normalize_value_for(:prontuario_sah, prontuario_sah),
      prontuario_aghuse: normalize_value_for(:prontuario_aghuse, prontuario_aghuse)
    }.compact
    encontrados = informados.filter_map { |campo, valor| find_by(campo => valor) }.uniq
    raise IdentificacaoInvalida, "Os prontuários SAH e AGHUSE pertencem a pacientes diferentes." if encontrados.size > 1

    paciente = encontrados.first or return
    if informados.any? { |campo, valor| paciente[campo].present? && paciente[campo] != valor }
      raise IdentificacaoInvalida, "Um dos prontuários não confere com o cadastro do paciente. Confira os dados."
    end
    iniciais = normalize_value_for(:iniciais, iniciais)
    if paciente.iniciais != iniciais
      raise IdentificacaoInvalida, iniciais ? "As iniciais não conferem com o paciente desse prontuário. Confira os dados." : "Informe as iniciais do paciente."
    end

    paciente
  end
end
