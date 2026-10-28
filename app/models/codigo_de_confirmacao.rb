# Código curto que a pessoa redigita para confirmar uma ação sensível (a troca
# da própria senha): evita a troca por engano ou com campos que o navegador
# preencheu sozinho. Fica na sessão (cookie criptografado), vale 10 minutos e
# serve uma vez só: conferido, certo ou errado, é descartado, e a tela mostra
# um novo. Não é um segundo fator: aparece na própria tela, porque o sistema
# não envia e-mail nem SMS.
class CodigoDeConfirmacao
  # Sem os caracteres que se confundem (0/O, 1/I/L, 2/Z, 5/S, 8/B)
  CARACTERES = %w[A C D E F G H J K M N P Q R T U V W X Y 3 4 6 7 9].freeze
  TAMANHO = 6
  VALIDADE = 10.minutes

  def initialize(session, acao)
    @session = session
    @chave = "codigo_de_confirmacao_#{acao}"
  end

  # Gera um código novo (o anterior deixa de valer) e o devolve no formato de
  # leitura, "ABC-123"
  def gerar
    codigo = Array.new(TAMANHO) { CARACTERES[SecureRandom.random_number(CARACTERES.size)] }.join
    @session[@chave] = { "codigo" => codigo, "expira_em" => VALIDADE.from_now.to_i }
    codigo.scan(/.{3}/).join("-")
  end

  # Aceita com ou sem o traço, em maiúsculas ou minúsculas
  def confere?(digitado)
    guardado = @session.delete(@chave)
    return false unless guardado.is_a?(Hash) && guardado["expira_em"].to_i > Time.current.to_i

    ActiveSupport::SecurityUtils.secure_compare(guardado["codigo"].to_s, digitado.to_s.gsub(/[\s-]/, "").upcase)
  end
end
