# Uma versão de um formulário. O rascunho (publicada_em nula) é o que o admin
# edita no gerador. Ao publicar, a versão congela: o model não deixa alterar
# nem apagar (readonly?), e as notificações registradas com ela continuam a
# segui-la para sempre. A mudança seguinte vira o rascunho da versão seguinte.
#
# estrutura é a definição em JSON, e só é gravada se o DefinicaoDeFormulario
# aceitar: o rascunho com as regras de rascunho (pode faltar finalidade, base
# legal e perguntas), a publicada com todas.
class VersaoFormulario < ApplicationRecord
  self.table_name = "versoes_formulario"

  # Definições publicadas já lidas, por versão: elas nunca mudam
  CACHE = Concurrent::Map.new
  MAXIMO_NO_CACHE = 500
  private_constant :CACHE, :MAXIMO_NO_CACHE

  # Antes de qualquer outra coisa (até da restrição das notificações): versão
  # publicada não sai sozinha, com ou sem notificações. Só sai junto com o
  # formulário inteiro (Formulario#destroy), que só é excluído sem notificações.
  before_destroy :manter_se_publicada, prepend: true

  belongs_to :formulario, inverse_of: :versoes
  belongs_to :publicada_por, class_name: "User", optional: true
  has_many :avaliacoes_clinicas, dependent: :restrict_with_error
  # Quem mexeu e quando ficam na auditoria; o conteúdo do rascunho a cada passo
  # não (seria uma cópia do JSON inteiro por clique). O da versão publicada é
  # a própria linha, que não muda mais.
  has_paper_trail skip: %i[estrutura]

  serialize :estrutura, coder: JSON

  attr_readonly :formulario_id, :numero
  validates :numero, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :formulario_id }
  # Publicação pela tela sempre tem autor (só a migração dos YAML antigos não tem)
  validates :publicada_por, presence: true, if: -> { publicada? && publicada_em_changed? }
  validate :estrutura_aceita
  # Grava a estrutura como o DefinicaoDeFormulario a devolve (textos limpos, só
  # campos conhecidos, padrões explícitos), nunca como chegou
  before_save :gravar_estrutura_canonica, if: :estrutura_changed?

  scope :publicadas, -> { where.not(publicada_em: nil) }

  def publicada?
    publicada_em.present?
  end

  def rascunho?
    !publicada?
  end

  # Depois de publicada, nada muda e nada é apagado (ActiveRecord::ReadOnlyRecord),
  # a não ser quando o formulário inteiro é excluído
  def readonly?
    (publicada_em_in_database.present? && !excluida_com_o_formulario?) || super
  end

  def estrutura=(valor)
    @definicao = nil
    super
  end

  def reload(*)
    @definicao = nil
    super
  end

  # A definição desta versão (DefinicaoDeFormulario). A publicada é lida uma
  # vez por processo; o rascunho, a cada mudança.
  def definicao
    return @definicao ||= DefinicaoDeFormulario.new(estrutura, rascunho: rascunho?) unless publicada? && persisted? && !changed?

    CACHE.clear if CACHE.size > MAXIMO_NO_CACHE
    CACHE.compute_if_absent([ id, publicada_em.utc.iso8601(6) ]) { DefinicaoDeFormulario.new(estrutura) }
  end

  # Publica o rascunho: confere a definição com todas as regras, congela esta
  # versão e a torna a que se preenche. O formulário fica travado durante a
  # publicação, e o lock_version recusa um rascunho que mudou depois de revisto.
  def publicar!(por:)
    raise ActiveRecord::RecordNotSaved.new("Só um rascunho pode ser publicado", self) unless rascunho? && persisted?

    transaction do
      formulario.lock!
      @definicao = nil
      self.publicada_em = Time.current
      self.publicada_por = por
      save!
      formulario.update!(versao_publicada: self)
    end
  rescue StandardError
    # Não publicou: o objeto volta a ser o rascunho que está no banco
    @definicao = nil
    restore_attributes(%w[publicada_em publicada_por_id])
    raise
  end

  private

  # A versão está sendo apagada pelo formulário dela (dependent: :destroy de
  # Formulario#versoes), e não sozinha
  def excluida_com_o_formulario?
    reflexao = destroyed_by_association
    reflexao.present? && reflexao.active_record == Formulario && reflexao.name == :versoes
  end

  def manter_se_publicada
    _raise_readonly_record_error if publicada_em_in_database.present? && !excluida_com_o_formulario?
  end

  def gravar_estrutura_canonica
    self.estrutura = definicao.estrutura.deep_dup
  end

  def estrutura_aceita
    @definicao = nil
    definicao
  rescue DefinicaoDeFormulario::DefinicaoInvalida => e
    e.erros.each { |erro| errors.add(:base, erro.mensagem) }
  end
end
