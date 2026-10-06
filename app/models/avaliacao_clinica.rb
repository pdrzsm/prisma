# Um formulário clínico preenchido. As respostas seguem a definição em
# config/formularios/<formulario>.yml (ver Formulario) e ficam cifradas.
class AvaliacaoClinica < ApplicationRecord
  belongs_to :paciente
  belongs_to :user # Quem registrou; as alterações seguintes ficam na auditoria
  has_paper_trail

  # Respostas do formulário em JSON; o documento inteiro é criptografado
  serialize :dados_formulario, coder: JSON
  encrypts :dados_formulario

  validates :formulario, inclusion: { in: ->(_) { Formulario.chaves } }
  before_validation :normalizar_respostas
  validate :respostas_conforme_formulario

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

  def normalizar_respostas
    self.dados_formulario = definicao.normalizar(dados_formulario || {}) if formulario_conhecido?
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
