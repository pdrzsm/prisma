class Paciente < ApplicationRecord
  class IdentificacaoInvalida < StandardError; end

  # Identificação pedida em todo formulário, antes das perguntas dele: o
  # cadastro do paciente no setor. Não faz parte do gerador de formulários,
  # porque é ela que liga as notificações ao paciente certo (Paciente.identificar).
  # O limite da tela das iniciais é maior que o do cadastro (10 letras): pontos
  # e espaços são tirados antes, então "M. S. S." cabe inteiro.
  IDENTIFICACAO = [
    [ "prontuario_sah", "Prontuário SAH", nil, nil ],
    [ "prontuario_aghuse", "Prontuário AGHUSE", nil, nil ],
    [ "iniciais", "Primeiras iniciais do nome", "abertura", "Até 10 letras, por exemplo: MSS. Pontos e espaços são ignorados." ]
  ].map do |chave, texto, obrigatoria, ajuda|
    DefinicaoDeFormulario::Pergunta.new(
      chave:, numero: nil, texto:, tipo: "texto", ajuda:, obrigatoria:, opcoes: [].freeze, minimo: nil, maximo: 30,
      decimais: nil, nao_maior_que: nil, nao_antes_de: nil, permite_futuro: false, condicao: nil, secao_id: nil, profundidade: 0
    )
  end.freeze

  # Cada setor tem os seus pacientes: o prontuário é único dentro do setor, e
  # o mesmo número em outro setor é outro cadastro
  belongs_to :setor
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
  validates :prontuario_sah, :prontuario_aghuse, length: { maximum: 30 }, uniqueness: { scope: :setor_id }, allow_nil: true

  # Busca por parte do prontuário (SAH ou AGHUSE) ou das iniciais, sem ligar
  # para maiúsculas, espaços e pontos. Prontuários e iniciais são cifrados no
  # banco, então a comparação é feita aqui, entre os pacientes dos registros que
  # a pessoa já pode ver (registros: um escopo de AvaliacaoClinica); devolve os
  # ids dos pacientes que combinam.
  def self.ids_que_combinam(registros, termo)
    busca = termo.to_s.gsub(/[\s.\-]/, "").upcase
    return [] if busca.empty?

    where(id: registros.select(:paciente_id)).select do |paciente|
      [ paciente.prontuario_sah, paciente.prontuario_aghuse, paciente.iniciais ].compact.any? { |valor| valor.gsub(/[\s.\-]/, "").include?(busca) }
    end.map(&:id)
  end

  # Sugestões para o autocomplete do filtro: prontuários e iniciais dos
  # pacientes dos registros visíveis, sem repetição e em ordem
  def self.sugestoes_de_busca(registros, limite: 200)
    where(id: registros.select(:paciente_id)).flat_map { |paciente| [ paciente.prontuario_sah, paciente.prontuario_aghuse, paciente.iniciais ] }
                                             .compact.uniq.sort.first(limite)
  end

  scope :com_prontuario, ->(prontuario) { where(prontuario_sah: prontuario).or(where(prontuario_aghuse: prontuario)) }

  # Localiza o paciente do setor pelos prontuários, sem alterar o cadastro
  # encontrado (paciente de outro setor nunca é encontrado). Recusa
  # (IdentificacaoInvalida) quando os dados informados não batem com o
  # cadastro: assim uma notificação não vai parar no paciente errado por causa
  # de um prontuário digitado errado.
  def self.identificar(setor:, prontuario_sah:, prontuario_aghuse:, iniciais:)
    informados = {
      prontuario_sah: normalize_value_for(:prontuario_sah, prontuario_sah),
      prontuario_aghuse: normalize_value_for(:prontuario_aghuse, prontuario_aghuse)
    }.compact
    encontrados = informados.filter_map { |campo, valor| find_by(setor:, campo => valor) }.uniq
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
