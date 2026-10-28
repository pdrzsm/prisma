# Um formulário clínico (ex.: avaliação nutricional), montado pelo admin no gerador
# de formulários (Configurações > Gerador de formulários). O conteúdo fica nas
# versões (VersaoFormulario): o rascunho, que o admin edita, e as publicadas,
# que nunca mudam. Quem preenche usa sempre a versão publicada mais recente;
# cada notificação fica ligada à versão em que foi registrada.
#
# A chave é o nome do formulário na URL (/formularios/<chave>/avaliacoes) e
# nas liberações. Ela é gerada a partir do título na criação e nunca muda (o
# banco também não deixa: as notificações e as liberações apontam para ela).
#
# Cada formulário pertence a uma instituição e é habilitado em setores dela,
# escolhidos já na criação (ainda rascunho: só passam a valer quando ele for
# publicado; ver Permissoes). A instituição só muda enquanto ele não estiver
# em nenhum setor.
class Formulario < ApplicationRecord
  CHAVE = DefinicaoDeFormulario::CHAVE
  # Seriam confundidas com as telas do gerador (/configuracoes/formularios/new)
  CHAVES_RESERVADAS = %w[new edit].freeze

  # Formulário com notificações nunca é excluído: o registro clínico é
  # preservado, e as versões dizem para que e com qual base legal cada dado foi
  # coletado (prestação de contas, LGPD). O banco também não deixa: as
  # notificações apontam para a chave. Sem nenhuma notificação, nada foi
  # coletado com ele, e ele sai inteiro, publicado ou não: as versões, as
  # habilitações nos setores e as liberações de quem o usava. Quem excluiu e
  # quando ficam na auditoria (PaperTrail). Roda antes de apagar o resto (prepend).
  before_destroy :conferir_exclusao, prepend: true

  has_many :versoes, -> { order(:numero) }, class_name: "VersaoFormulario", inverse_of: :formulario, dependent: :destroy
  has_one :rascunho, -> { where(publicada_em: nil) }, class_name: "VersaoFormulario", inverse_of: :formulario
  belongs_to :versao_publicada, class_name: "VersaoFormulario", optional: true
  belongs_to :instituicao, inverse_of: :formularios
  # Os setores em que está habilitado e as pessoas liberadas nele (as duas
  # tabelas guardam a chave). Saem com o formulário, que nunca teve notificações.
  has_many :habilitacoes, class_name: "FormularioHabilitado", foreign_key: :formulario, primary_key: :chave,
                          inverse_of: false, dependent: :destroy
  has_many :liberacoes, class_name: "LiberacaoFormulario", foreign_key: :formulario, primary_key: :chave,
                        inverse_of: false, dependent: :destroy
  has_paper_trail

  attr_readonly :chave
  validates :chave, format: { with: CHAVE }, exclusion: { in: CHAVES_RESERVADAS }, uniqueness: true
  validate :versao_publicada_deste_formulario
  validate :instituicao_fixa_enquanto_em_setores, on: :update

  scope :publicados, -> { where.not(versao_publicada_id: nil) }

  class << self
    # Os formulários que se pode preencher (publicados), em ordem de título
    def todos
      publicados.includes(:versao_publicada).sort_by { |formulario| I18n.transliterate(formulario.titulo).downcase }
    end

    def chaves
      publicados.pluck(:chave)
    end

    # Publicado pela chave da URL; os outros (e chave inexistente) dão 404
    def publicado!(chave)
      publicados.find_by!(chave: chave.to_s)
    end

    # Chave nova a partir do título ("Avaliação nutricional" vira "avaliacao_nutricional"),
    # sem repetir uma que já existe
    def chave_para(titulo)
      base = I18n.transliterate(TextoSeguro.linha(titulo)).downcase.gsub(/[^a-z0-9]+/, "_").sub(/\A[_0-9]+/, "").first(50).delete_suffix("_")
      base = "formulario" if base.empty?
      candidata = base
      candidata = "#{base}_#{(numero = (numero || 1) + 1)}" while CHAVES_RESERVADAS.include?(candidata) || exists?(chave: candidata)
      candidata
    end
  end

  def to_param
    chave
  end

  def publicado?
    versao_publicada_id.present?
  end

  # Definição da versão publicada (quem preenche usa esta)
  def definicao
    versao_publicada&.definicao
  end

  # As notificações registradas com este formulário, em qualquer versão e setor
  def notificacoes
    AvaliacaoClinica.where(formulario: chave)
  end

  # Sem nenhuma notificação, nada foi coletado com ele e ele pode ser excluído
  def excluivel?
    !notificacoes.exists?
  end

  # Para o gerador: a publicada ou, se o formulário nunca foi publicado, o rascunho
  def definicao_atual
    (versao_publicada || rascunho)&.definicao
  end

  delegate :titulo, :descricao, :finalidade, :base_legal, to: :definicao_atual, allow_nil: true

  # Deixa o formulário habilitado exatamente nestes setores. Só entram setores
  # da instituição dele. Tirar de um setor tira também as liberações do
  # formulário nele; um setor com notificações do formulário não sai (o erro
  # vai para errors), nem um de outra instituição que já o tinha antes da
  # regra, se tiver notificações. Devolve true se deu tudo certo.
  def habilitar_em(setor_ids)
    ids = Array(setor_ids).filter_map { |id| Integer(id.to_s, 10, exception: false) }
    transaction do
      habilitacoes.reject { |habilitacao| ids.include?(habilitacao.setor_id) }.each do |habilitacao|
        if habilitacao.destroy
          LiberacaoFormulario.where(setor_id: habilitacao.setor_id, formulario: chave).destroy_all
        else
          errors.merge!(habilitacao.errors)
        end
      end
      novos = instituicao.setores.where(id: ids).pluck(:id) - habilitacoes.map(&:setor_id)
      novos.each { |setor_id| habilitacoes.create!(setor_id:) }
    end
    habilitacoes.reset
    errors.empty?
  end

  private

  def instituicao_fixa_enquanto_em_setores
    return unless instituicao_id_changed? && habilitacoes.exists?

    errors.add(:instituicao, "só muda enquanto o formulário não está em nenhum setor")
  end

  def versao_publicada_deste_formulario
    return unless versao_publicada
    return if versao_publicada.formulario_id == id && versao_publicada.publicada?

    errors.add(:versao_publicada, "precisa ser uma versão publicada deste formulário")
  end

  def conferir_exclusao
    unless excluivel?
      errors.add(:base, "Formulário com notificações não é excluído: o registro clínico é preservado")
      throw :abort
    end

    # O formulário e a versão publicada se apontam (chaves estrangeiras): solta
    # um lado para apagar os dois. Se algo falhar depois, tudo volta (transação).
    update!(versao_publicada: nil) if versao_publicada_id
  end
end
