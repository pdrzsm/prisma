class AvaliacaoClinica < ApplicationRecord
  # Limites do JSON livre do formulário, até cada formulário ter seu próprio
  # schema de campos (ver docs/novo-formulario.md)
  NOME_DE_CAMPO = /\A[a-z0-9_]{1,64}\z/
  MAXIMO_DE_CAMPOS = 300
  MAXIMO_DE_BYTES = 64.kilobytes

  belongs_to :paciente
  belongs_to :user # Quem registrou
  has_paper_trail

  # Respostas do formulário em JSON; o documento inteiro é criptografado
  serialize :dados_formulario, coder: JSON
  encrypts :dados_formulario

  validates :dados_formulario, presence: true
  validate :formato_dos_dados_formulario

  private

  def formato_dos_dados_formulario
    return if dados_formulario.blank?
    return errors.add(:dados_formulario, "deve ser um conjunto de campos") unless dados_formulario.is_a?(Hash)

    errors.add(:dados_formulario, "tem campos demais") if dados_formulario.size > MAXIMO_DE_CAMPOS
    errors.add(:dados_formulario, "é grande demais") if dados_formulario.to_json.bytesize > MAXIMO_DE_BYTES
    errors.add(:dados_formulario, "tem nome de campo inválido") unless dados_formulario.keys.all? { |campo| campo.to_s.match?(NOME_DE_CAMPO) }
    errors.add(:dados_formulario, "aceita só textos, números, booleanos ou listas deles") unless dados_formulario.values.all? { |valor| valor_simples?(valor) || lista_simples?(valor) }
  end

  def valor_simples?(valor)
    valor.nil? || valor.is_a?(String) || valor.is_a?(Numeric) || valor == true || valor == false
  end

  def lista_simples?(valor)
    valor.is_a?(Array) && valor.all? { |item| valor_simples?(item) }
  end
end
