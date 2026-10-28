# Avisos da revisão antes de publicar um formulário (LGPD, art. 6º, III:
# minimização). O Prisma identifica o paciente só por prontuário e iniciais;
# uma pergunta que pede um dado que identifica a pessoa diretamente (CPF, nome
# completo, endereço, telefone...) precisa de um bom motivo. O aviso não
# impede a publicação: quem decide, com o encarregado (DPO), é a instituição.
#
# A procura é pelo enunciado e pelo texto de ajuda, sem acentos e sem
# diferenciar maiúsculas. É uma lista curta e conhecida, não uma garantia: a
# revisão de quem publica continua necessária.
module AvisosDeMinimizacao
  Aviso = Data.define(:pergunta, :motivo)

  PADROES = {
    /\bcpf\b/ => "CPF",
    /\brg\b|carteira de identidade|\bidentidade\b/ => "documento de identidade",
    /\bnome (completo|do paciente|da paciente|da mae|do pai|social)\b|\bnome\s*$/ => "nome da pessoa",
    /cartao (do )?sus|cartao nacional de saude|\bcns\b/ => "Cartão Nacional de Saúde",
    /endereco|logradouro|\bcep\b/ => "endereço",
    /telefone|celular|whatsapp/ => "telefone",
    /\be-?mail\b/ => "e-mail",
    /data d[eo] nascimento/ => "data de nascimento",
    /passaporte|titulo de eleitor/ => "documento",
    /prontuario/ => "prontuário (a identificação do paciente já pede os prontuários)"
  }.freeze

  module_function

  def para(definicao)
    definicao.perguntas.filter_map do |pergunta|
      texto = I18n.transliterate([ pergunta.texto, pergunta.ajuda ].compact.join(" ")).downcase
      motivo = PADROES.find { |padrao, _| texto.match?(padrao) }&.last
      Aviso.new(pergunta:, motivo:) if motivo
    end
  end

  # Texto livre pode receber qualquer coisa, inclusive o que não devia
  def tem_texto_livre?(definicao)
    definicao.perguntas.any? { |pergunta| pergunta.tipo == "texto_longo" }
  end
end
