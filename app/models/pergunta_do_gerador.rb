# A tela de uma pergunta no gerador de formulários: recebe o que o admin
# digitou, confere campo a campo (para cada erro aparecer ao lado do seu
# campo) e monta a pergunta no formato da estrutura (atributos). Só os campos
# do tipo escolhido são lidos; os outros, mesmo preenchidos, são ignorados.
#
# As opções são digitadas uma por linha, no formato "código, rótulo"
# (ex.: "1, Positiva"), como no formulário em papel e no SINAN. O código é
# obrigatório: um rótulo com vírgula ("Sim, com restrições") nunca é cortado
# no lugar errado sem aviso.
#
# A definição inteira ainda passa pelo DefinicaoDeFormulario ao gravar: esta
# classe só deixa as mensagens mais claras, não substitui aquela conferência.
class PerguntaDoGerador
  include ActiveModel::Model
  include ActiveModel::Attributes

  CAMPOS = %i[texto tipo ajuda obrigatoria numero limite minimo maximo decimais nao_maior_que nao_antes_de
              permite_futuro opcoes exclusivas].freeze
  OPCAO = /\A\s*([^,\s]+)\s*,\s*(.+?)\s*\z/

  CAMPOS.each { |campo| attribute campo, :string }
  attribute :valores, default: -> { [] }

  # numeracao_manual: o formulário usa os números do papel, e a pergunta
  # precisa do dela. controladora: a pergunta de que esta depende (só ela
  # tem valores, as opções que a mostram).
  attr_accessor :numeracao_manual, :controladora

  validates :texto, presence: true, length: { maximum: DefinicaoDeFormulario::TAMANHOS[:texto] }
  validates :tipo, inclusion: { in: DefinicaoDeFormulario::TIPOS.keys, message: "escolha um tipo da lista" }
  validates :obrigatoria, inclusion: { in: [ "", "abertura", "encerramento" ], message: "escolha uma das opções" }
  validates :ajuda, length: { maximum: DefinicaoDeFormulario::TAMANHOS[:ajuda] }
  validates :numero, presence: true, format: { with: DefinicaoDeFormulario::NUMERO, message: "use até 10 letras, números, ponto ou traço" },
                     if: :numeracao_manual
  validate :campos_do_tipo
  validate :valores_da_condicao, if: :controladora

  # A tela de edição, a partir da pergunta gravada
  def self.de(pergunta, numeracao_manual:, controladora: nil)
    new(
      texto: pergunta.texto, tipo: pergunta.tipo, ajuda: pergunta.ajuda, obrigatoria: pergunta.obrigatoria.to_s,
      numero: (pergunta.numero if numeracao_manual), limite: (pergunta.maximo if pergunta.tipo.start_with?("texto")),
      minimo: (pergunta.minimo if pergunta.tipo == "numero"), maximo: (pergunta.maximo if pergunta.tipo == "numero"),
      decimais: pergunta.decimais, nao_maior_que: pergunta.nao_maior_que, nao_antes_de: pergunta.nao_antes_de,
      permite_futuro: pergunta.permite_futuro ? "1" : "0",
      opcoes: pergunta.opcoes.map { |opcao| "#{opcao.codigo}, #{opcao.rotulo}" }.join("\n"),
      exclusivas: pergunta.opcoes.select(&:exclusiva).map(&:codigo).join(", "),
      valores: pergunta.condicao&.valores.to_a,
      numeracao_manual:, controladora:
    )
  end

  def tipo
    super.presence || "texto"
  end

  # Sem a escolha na requisição, não é obrigatória
  def obrigatoria
    super.to_s
  end

  def numero
    super.to_s.strip.presence
  end

  # As opções que mostram a pergunta dependente, sem o vazio que o campo
  # escondido da tela manda (para a lista chegar mesmo com tudo desmarcado)
  def valores
    Array(super).map(&:to_s).compact_blank.uniq
  end

  def escolha?
    DefinicaoDeFormulario::TIPOS_DE_ESCOLHA.include?(tipo)
  end

  # A pergunta no formato da estrutura, sem chave nem condição (quem acrescenta
  # é o EdicaoDoRascunho). Só depois de valid?.
  def atributos
    {
      "numero" => (numero if numeracao_manual), "texto" => texto, "tipo" => tipo, "ajuda" => ajuda.presence,
      "obrigatoria" => obrigatoria.presence
    }.merge(atributos_do_tipo).compact
  end

  # Opções lidas da caixa de texto: [[código, rótulo], ...]. Linha em branco é ignorada.
  def opcoes_lidas
    opcoes.to_s.lines.map(&:strip).compact_blank.filter_map { |linha| linha.match(OPCAO)&.captures }
  end

  def codigos_exclusivos
    exclusivas.to_s.split(/[,\s]+/).compact_blank.uniq
  end

  private

  def atributos_do_tipo
    case tipo
    when "texto", "texto_longo" then { "maximo" => inteiro(limite) || DefinicaoDeFormulario::CARACTERES_PADRAO.fetch(tipo) }
    when "numero"
      { "minimo" => inteiro(minimo) || DefinicaoDeFormulario::MINIMO_PADRAO, "maximo" => inteiro(maximo) || DefinicaoDeFormulario::MAXIMO_PADRAO,
        "decimais" => inteiro(decimais) || 0, "nao_maior_que" => nao_maior_que.presence }
    when "data" then { "permite_futuro" => permite_futuro == "1", "nao_antes_de" => nao_antes_de.presence }
    else
      exclusivas = codigos_exclusivos
      { "opcoes" => opcoes_lidas.map do |codigo, rotulo|
        { "codigo" => codigo, "rotulo" => rotulo, "exclusiva" => (true if tipo == "multipla" && exclusivas.include?(codigo)) }.compact
      end }
    end
  end

  def campos_do_tipo
    case tipo
    when "texto", "texto_longo"
      faixa = DefinicaoDeFormulario::CARACTERES.fetch(tipo)
      conferir_inteiro(:limite, faixa)
    when "numero"
      faixa = -DefinicaoDeFormulario::NUMERO_ABSOLUTO..DefinicaoDeFormulario::NUMERO_ABSOLUTO
      conferir_inteiro(:minimo, faixa)
      conferir_inteiro(:maximo, faixa)
      conferir_inteiro(:decimais, DefinicaoDeFormulario::DECIMAIS)
      errors.add(:maximo, "não pode ser menor que o mínimo") if inteiro(minimo) && inteiro(maximo) && inteiro(minimo) > inteiro(maximo)
    when *DefinicaoDeFormulario::TIPOS_DE_ESCOLHA then conferir_opcoes
    end
  end

  def conferir_opcoes
    linhas = opcoes.to_s.lines.map(&:strip).compact_blank
    return errors.add(:opcoes, "escreva pelo menos uma opção") if linhas.empty?
    if linhas.size > DefinicaoDeFormulario::MAXIMO_DE_OPCOES
      return errors.add(:opcoes, "no máximo #{DefinicaoDeFormulario::MAXIMO_DE_OPCOES} opções")
    end

    linhas.each_with_index do |linha, indice|
      codigo, rotulo = linha.match(OPCAO)&.captures
      next errors.add(:opcoes, "linha #{indice + 1}: use o formato código, rótulo (ex.: 1, Sim)") unless codigo
      next errors.add(:opcoes, "linha #{indice + 1}: o código usa até 16 letras, números, ponto, traço ou sublinhado") unless codigo.match?(DefinicaoDeFormulario::CODIGO)

      errors.add(:opcoes, "linha #{indice + 1}: o rótulo tem mais de #{DefinicaoDeFormulario::TAMANHOS[:rotulo]} caracteres") if rotulo.length > DefinicaoDeFormulario::TAMANHOS[:rotulo]
    end
    codigos = opcoes_lidas.map(&:first)
    errors.add(:opcoes, "há códigos repetidos") if codigos.uniq.size != codigos.size
    errors.add(:opcoes, "há rótulos repetidos") if opcoes_lidas.map { |_, rotulo| rotulo.downcase }.uniq.size != codigos.size

    return unless tipo == "multipla"

    inexistentes = codigos_exclusivos - codigos
    errors.add(:exclusivas, "use só códigos das opções (#{inexistentes.join(', ')} não está)") if inexistentes.any?
  end

  def valores_da_condicao
    return errors.add(:valores, "escolha pelo menos uma opção que mostra esta pergunta") if valores.empty?

    errors.add(:valores, "escolha só opções da pergunta “#{controladora.texto}”") unless (valores - controladora.codigos).empty?
  end

  def conferir_inteiro(campo, faixa)
    valor = public_send(campo)
    return if valor.blank?

    errors.add(campo, "use um número inteiro de #{faixa.min} a #{faixa.max}") unless inteiro(valor) && faixa.cover?(inteiro(valor))
  end

  def inteiro(valor)
    Integer(valor.to_s.strip, 10, exception: false) if valor.present?
  end
end
