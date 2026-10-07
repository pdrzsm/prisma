# Um formulário clínico preenchido. As respostas seguem a definição em
# config/formularios/<formulario>.yml (ver Formulario) e ficam cifradas.
class AvaliacaoClinica < ApplicationRecord
  belongs_to :paciente
  belongs_to :user # Quem registrou; as alterações seguintes ficam na auditoria
  # Setor da notificação: o mesmo do paciente. É por ele que as liberações
  # filtram quem vê e quem registra (ver Permissoes)
  belongs_to :setor
  has_paper_trail

  # Respostas do formulário em JSON; o documento inteiro é criptografado
  serialize :dados_formulario, coder: JSON
  encrypts :dados_formulario

  validates :formulario, inclusion: { in: ->(_) { Formulario.chaves } }
  # O setor nunca muda depois do registro (tiraria a notificação de quem a vê)
  attr_readonly :setor_id
  # Para que e com qual base legal a notificação foi coletada (LGPD, art. 6º,
  # X): copiadas do formulário no registro e nunca mais alteradas, mesmo que a
  # definição do formulário mude depois
  attr_readonly :finalidade, :base_legal
  before_validation :registrar_finalidade, on: :create
  validates :finalidade, :base_legal, presence: true
  before_validation :normalizar_respostas
  validate :respostas_conforme_formulario
  validate :mesmo_setor_do_paciente
  validate :formulario_habilitado_no_setor, on: :create

  def definicao
    Formulario.find(formulario)
  end

  def respostas
    dados_formulario.is_a?(Hash) ? dados_formulario : {}
  end

  def encerrada?
    definicao.encerrada?(respostas)
  end

  # Erros da última validação, por pergunta, para mostrar ao lado de cada uma
  def erros_da_pergunta(chave)
    @erros_por_pergunta.to_h.fetch(chave.to_s, [])
  end

  private

  def formulario_conhecido?
    Formulario.chaves.include?(formulario)
  end

  def registrar_finalidade
    return unless formulario_conhecido?

    self.finalidade = definicao.finalidade
    self.base_legal = definicao.base_legal
  end

  def normalizar_respostas
    self.dados_formulario = definicao.normalizar(dados_formulario || {}) if formulario_conhecido?
  end

  def mesmo_setor_do_paciente
    errors.add(:setor, "é diferente do setor do paciente") if paciente && setor_id != paciente.setor_id
  end

  def formulario_habilitado_no_setor
    return if setor_id.nil? || FormularioHabilitado.exists?(setor_id:, formulario:)

    errors.add(:formulario, "não está habilitado neste setor")
  end

  def respostas_conforme_formulario
    return unless formulario_conhecido?

    @erros_por_pergunta = definicao.validar(dados_formulario)
    @erros_por_pergunta.each do |chave, mensagens|
      pergunta = definicao.pergunta(chave)
      prefixo = pergunta ? "#{pergunta.numero}. #{pergunta.texto}" : "Formulário"
      mensagens.each { |mensagem| errors.add(:base, "#{prefixo}: #{mensagem}") }
    end
  end
end
