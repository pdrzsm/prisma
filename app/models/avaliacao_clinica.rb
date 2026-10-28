# Um formulário clínico preenchido. As respostas seguem a versão do formulário
# em que a notificação foi registrada (versao_formulario, ver
# DefinicaoDeFormulario) e ficam cifradas.
class AvaliacaoClinica < ApplicationRecord
  belongs_to :paciente
  belongs_to :user # Quem registrou; as alterações seguintes ficam na auditoria
  # Setor da notificação: o mesmo do paciente. É por ele que as liberações
  # filtram quem vê e quem registra (ver Permissoes)
  belongs_to :setor
  # A versão publicada do formulário quando a notificação foi registrada. Uma
  # versão nova do formulário não muda as perguntas nem os códigos desta
  # notificação: ela continua sendo lida e editada com a versão dela
  belongs_to :versao_formulario
  has_paper_trail

  # Respostas do formulário em JSON; o documento inteiro é criptografado
  serialize :dados_formulario, coder: JSON
  encrypts :dados_formulario

  # O setor, o formulário e a versão nunca mudam depois do registro (mudar
  # tiraria a notificação de quem a vê ou trocaria o sentido das respostas)
  attr_readonly :setor_id, :formulario, :versao_formulario_id
  # Para que e com qual base legal a notificação foi coletada (LGPD, art. 6º,
  # X): copiadas da versão do formulário no registro e nunca mais alteradas
  attr_readonly :finalidade, :base_legal
  before_validation :vincular_versao_publicada, on: :create
  before_validation :registrar_finalidade, on: :create
  before_validation :normalizar_respostas
  validates :finalidade, :base_legal, presence: true
  validate :versao_do_formulario
  validate :respostas_conforme_formulario
  validate :mesmo_setor_do_paciente
  validate :formulario_habilitado_no_setor, on: :create

  # Quem fez a última alteração de cada notificação, para a coluna "Atualizada
  # por" das listas: { id da notificação => usuário }. Vem da auditoria
  # (PaperTrail), numa consulta só; sem alteração registrada, é quem registrou.
  def self.autores_da_ultima_alteracao(avaliacoes)
    ultimas = PaperTrail::Version.where(item_type: name, item_id: avaliacoes.map(&:id)).order(:id)
                                 .pluck(:item_id, :whodunnit).to_h
    usuarios = User.where(id: ultimas.values.filter_map { |id| Integer(id.to_s, exception: false) }).index_by(&:id)
    avaliacoes.to_h do |avaliacao|
      autor = usuarios[Integer(ultimas[avaliacao.id].to_s, exception: false)]
      [ avaliacao.id, autor || avaliacao.user ]
    end
  end

  # Definição que esta notificação segue (nil só num registro inválido, sem versão)
  def definicao
    versao_formulario&.definicao
  end

  def respostas
    dados_formulario.is_a?(Hash) ? dados_formulario : {}
  end

  def encerrada?
    definicao&.encerrada?(respostas) || false
  end

  # Erros da última validação, por pergunta, para mostrar ao lado de cada uma
  def erros_da_pergunta(chave)
    @erros_por_pergunta.to_h.fetch(chave.to_s, [])
  end

  private

  # A notificação nova segue a versão publicada agora; nunca uma vinda da tela
  def vincular_versao_publicada
    self.versao_formulario ||= Formulario.publicados.find_by(chave: formulario)&.versao_publicada
  end

  def versao_valida?
    versao_formulario&.publicada? && versao_formulario.formulario.chave == formulario
  end

  def versao_do_formulario
    if !versao_valida?
      errors.add(:formulario, "não existe ou ainda não foi publicado")
    elsif new_record? && versao_formulario.formulario.versao_publicada_id != versao_formulario.id
      errors.add(:versao_formulario, "não é a versão atual do formulário")
    end
  end

  def registrar_finalidade
    return unless versao_valida?

    self.finalidade = definicao.finalidade
    self.base_legal = definicao.base_legal
  end

  def normalizar_respostas
    self.dados_formulario = definicao.normalizar(dados_formulario || {}) if versao_valida?
  end

  def mesmo_setor_do_paciente
    errors.add(:setor, "é diferente do setor do paciente") if paciente && setor_id != paciente.setor_id
  end

  def formulario_habilitado_no_setor
    return if setor_id.nil? || FormularioHabilitado.exists?(setor_id:, formulario:)

    errors.add(:formulario, "não está habilitado neste setor")
  end

  def respostas_conforme_formulario
    return unless versao_valida?

    @erros_por_pergunta = definicao.validar(dados_formulario)
    @erros_por_pergunta.each do |chave, mensagens|
      pergunta = definicao.pergunta(chave)
      prefixo = pergunta ? "#{pergunta.numero}. #{pergunta.texto}" : "Formulário"
      mensagens.each { |mensagem| errors.add(:base, "#{prefixo}: #{mensagem}") }
    end
  end
end
