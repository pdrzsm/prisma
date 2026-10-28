# Definições de formulário usadas nos testes. O Prisma não traz formulário
# nenhum: numa instalação, cada um é montado pelo admin no gerador. Aqui:
#
# - ACOMPANHAMENTO: o formulário das fixtures (test/fixtures/formularios.yml),
#   fictício, no jeito de um formulário em papel: numeração manual (pulando o
#   4, como se fosse a identificação do paciente), obrigatórias de abertura e
#   "para encerrar", uma pergunta que depende de outra, opções exclusivas e
#   limites entre perguntas;
# - TODOS_OS_TIPOS: cada tipo de pergunta e condições em três níveis.
#
# Os dois são preenchidos de ponta a ponta em
# test/integration/formularios_completos_test.rb e no navegador.
module FormulariosDeTeste
  def self.opcoes(*rotulos, exclusivas: [])
    rotulos.each_with_index.map do |rotulo, indice|
      codigo = (indice + 1).to_s
      { "codigo" => codigo, "rotulo" => rotulo, "exclusiva" => exclusivas.include?(codigo) }
    end
  end

  TODOS_OS_TIPOS = {
    "titulo" => "Todos os tipos",
    "descricao" => "Formulário de teste com cada tipo de pergunta.\nE uma segunda linha.",
    "finalidade" => "testar o preenchimento de cada tipo de pergunta",
    "base_legal" => "nenhuma, é um teste",
    "encerramento" => "encerrado_em",
    "lista" => %w[apelido gravidade],
    "secoes" => [
      {
        "id" => "s1", "titulo" => "Básico", "descricao" => "Perguntas sem condição.",
        "perguntas" => [
          { "chave" => "apelido", "texto" => "Apelido", "tipo" => "texto", "maximo" => 40, "obrigatoria" => "abertura" },
          { "chave" => "relato", "texto" => "Relato", "tipo" => "texto_longo", "maximo" => 500, "ajuda" => "Pode ter\nvárias linhas." },
          { "chave" => "contatos", "texto" => "Contatos", "tipo" => "numero", "minimo" => 0, "maximo" => 100 },
          { "chave" => "avaliados", "texto" => "Contatos avaliados", "tipo" => "numero", "maximo" => 100, "nao_maior_que" => "contatos" },
          { "chave" => "peso", "texto" => "Peso (kg)", "tipo" => "numero", "decimais" => 2, "minimo" => 1, "maximo" => 300 },
          { "chave" => "inicio", "texto" => "Início", "tipo" => "data" },
          { "chave" => "retorno", "texto" => "Retorno previsto", "tipo" => "data", "permite_futuro" => true, "nao_antes_de" => "inicio" }
        ]
      },
      {
        "id" => "s2", "titulo" => "Condições",
        "perguntas" => [
          { "chave" => "gravidade", "texto" => "Gravidade", "tipo" => "lista_suspensa", "obrigatoria" => "abertura",
            "opcoes" => opcoes("Grave", "Leve") },
          { "chave" => "internado", "texto" => "Internado?", "tipo" => "unica", "opcoes" => opcoes("Sim", "Não"),
            "condicao" => { "pergunta" => "gravidade", "valores" => [ "1" ] } },
          { "chave" => "uti", "texto" => "Na UTI?", "tipo" => "unica", "opcoes" => opcoes("Sim", "Não"),
            "condicao" => { "pergunta" => "internado", "valores" => [ "1" ] } },
          { "chave" => "dias_de_uti", "texto" => "Dias na UTI", "tipo" => "numero", "maximo" => 365,
            "condicao" => { "pergunta" => "uti", "valores" => [ "1" ] } },
          { "chave" => "sintomas", "texto" => "Sintomas", "tipo" => "multipla",
            "opcoes" => opcoes("Febre", "Tosse", "Nenhum", exclusivas: [ "3" ]) },
          { "chave" => "temperatura", "texto" => "Temperatura máxima", "tipo" => "numero", "decimais" => 1, "minimo" => 30, "maximo" => 45,
            "obrigatoria" => "abertura", "condicao" => { "pergunta" => "sintomas", "valores" => [ "1" ] } },
          { "chave" => "dias_de_tosse", "texto" => "Dias de tosse", "tipo" => "numero",
            "condicao" => { "pergunta" => "sintomas", "valores" => [ "2" ] } }
        ]
      },
      {
        "id" => "s3", "titulo" => "Desfecho",
        "perguntas" => [
          { "chave" => "desfecho", "texto" => "Desfecho", "tipo" => "unica", "obrigatoria" => "encerramento",
            "opcoes" => opcoes("Alta", "Óbito") },
          { "chave" => "encerrado_em", "texto" => "Encerrado em", "tipo" => "data" }
        ]
      }
    ]
  }.freeze

  RESULTADO = opcoes("Positivo", "Negativo", "Não realizado", "Não se aplica").freeze
  IMAGEM = opcoes("Alterada", "Normal", "Outra alteração", "Não realizada", exclusivas: %w[2 4]).freeze
  NAO_SIM = [ { "codigo" => "0", "rotulo" => "Não", "exclusiva" => false }, { "codigo" => "1", "rotulo" => "Sim", "exclusiva" => false } ].freeze

  # Opções com códigos escolhidos (como no papel), e não 1, 2, 3...
  def self.codigos(pares, exclusivas: [])
    pares.map { |codigo, rotulo| { "codigo" => codigo, "rotulo" => rotulo, "exclusiva" => exclusivas.include?(codigo) } }
  end

  ACOMPANHAMENTO = {
    "titulo" => "Acompanhamento de teste",
    "descricao" => "Formulário fictício dos testes, do registro ao encerramento.",
    "finalidade" => "acompanhar casos fictícios nos testes do sistema",
    "base_legal" => "nenhuma, é um teste",
    "numeracao" => "manual",
    "encerramento" => "data_encerramento",
    "lista" => %w[numero_registro forma],
    "secoes" => [
      {
        "id" => "s1", "titulo" => "Identificação do registro",
        "perguntas" => [
          { "numero" => "3", "chave" => "numero_registro", "texto" => "Número do registro", "tipo" => "texto", "maximo" => 30 }
        ]
      },
      {
        "id" => "s2", "titulo" => "Dados do paciente",
        "perguntas" => [
          { "numero" => "5", "chave" => "gestante", "texto" => "Gestante?", "tipo" => "unica", "obrigatoria" => "abertura",
            "opcoes" => codigos([ %w[1 1º\ trimestre], %w[2 2º\ trimestre], %w[3 3º\ trimestre], [ "4", "Idade gestacional ignorada" ],
                                  %w[5 Não], [ "6", "Não se aplica" ], %w[9 Ignorado] ]) },
          { "numero" => "6", "chave" => "populacoes_especiais", "texto" => "Populações especiais", "tipo" => "multipla", "obrigatoria" => "abertura",
            "opcoes" => codigos([ %w[0 Não], [ "1", "Em situação de rua" ], [ "2", "Privada de liberdade" ], [ "3", "Profissional de saúde" ],
                                  %w[4 Imigrante] ], exclusivas: %w[0]) },
          { "numero" => "7", "chave" => "recebe_beneficio", "texto" => "Recebe algum benefício?", "tipo" => "unica", "obrigatoria" => "abertura",
            "opcoes" => codigos([ %w[0 Não], %w[1 Sim], %w[2 Ignorado] ]) },
          { "numero" => "8", "chave" => "municipio_residencia", "texto" => "Município de residência", "tipo" => "texto", "maximo" => 100,
            "obrigatoria" => "abertura" },
          { "numero" => "9", "chave" => "forma", "texto" => "Forma", "tipo" => "unica", "obrigatoria" => "abertura",
            "opcoes" => opcoes("Localizada", "Disseminada", "Localizada + disseminada") },
          { "numero" => "10", "chave" => "locais", "texto" => "Se disseminada, onde?", "tipo" => "multipla", "obrigatoria" => "abertura",
            "condicao" => { "pergunta" => "forma", "valores" => %w[2 3] },
            "opcoes" => opcoes("Pele", "Articulações", "Ossos", "Rins", "Fígado", "Pulmões", "Sistema nervoso", "Olhos", "Intestino", "Outro") }
        ]
      },
      {
        "id" => "s3", "titulo" => "Exames",
        "perguntas" => [
          { "numero" => "11", "chave" => "exame_mes_1", "texto" => "Exame do 1º mês", "tipo" => "unica", "obrigatoria" => "encerramento", "opcoes" => RESULTADO },
          { "numero" => "12", "chave" => "exame_mes_2", "texto" => "Exame do 2º mês", "tipo" => "unica", "obrigatoria" => "encerramento", "opcoes" => RESULTADO },
          { "numero" => "13", "chave" => "cultura", "texto" => "Cultura", "tipo" => "unica",
            "opcoes" => opcoes("Sensível", "Resistente", "Em andamento", "Não realizada") },
          { "numero" => "14", "chave" => "outro_material", "texto" => "Outro material?", "tipo" => "unica", "obrigatoria" => "encerramento",
            "opcoes" => codigos([ %w[0 Não], %w[1 Líquor], %w[2 Urina], %w[9 Outro] ]) },
          { "numero" => "15", "chave" => "exame_imagem", "texto" => "Exame de imagem", "tipo" => "unica", "obrigatoria" => "encerramento",
            "opcoes" => opcoes("Alterado", "Normal", "Outra alteração", "Não realizado") },
          { "numero" => "16", "chave" => "imagem_complementar", "texto" => "Imagem complementar", "tipo" => "multipla", "opcoes" => IMAGEM }
        ]
      },
      {
        "id" => "s4", "titulo" => "Tratamento",
        "perguntas" => [
          { "numero" => "17", "chave" => "contagem_final", "texto" => "Contagem no fim do tratamento", "tipo" => "numero", "maximo" => 5000 },
          { "numero" => "18", "chave" => "mudanca_tratamento", "texto" => "Mudança de tratamento", "tipo" => "unica", "obrigatoria" => "encerramento",
            "opcoes" => NAO_SIM },
          { "numero" => "19", "chave" => "motivo_mudanca_tratamento", "texto" => "Motivo da mudança de tratamento", "tipo" => "texto_longo", "maximo" => 500 },
          { "numero" => "20", "chave" => "comorbidades", "texto" => "Comorbidades", "tipo" => "multipla",
            "opcoes" => codigos([ %w[0 Não], %w[1 Diabetes], %w[2 Hipertensão], %w[3 Tabagismo] ], exclusivas: %w[0]) }
        ]
      },
      {
        "id" => "s5", "titulo" => "Desfecho",
        "perguntas" => [
          { "numero" => "21", "chave" => "desfecho", "texto" => "Desfecho", "tipo" => "unica",
            "opcoes" => opcoes("Cura", "Abandono", "Óbito", "Transferência", "Mudança de diagnóstico") },
          { "numero" => "22", "chave" => "numero_contatos", "texto" => "Número de contatos", "tipo" => "numero", "maximo" => 1000 },
          { "numero" => "23", "chave" => "numero_contatos_avaliados", "texto" => "Número de contatos avaliados", "tipo" => "numero", "maximo" => 1000,
            "nao_maior_que" => "numero_contatos" },
          { "numero" => "24", "chave" => "data_encerramento", "texto" => "Encerramento", "tipo" => "data",
            "ajuda" => "Ao preencher, as perguntas marcadas “para encerrar” passam a ser obrigatórias." },
          { "numero" => "25", "chave" => "data_revisao_encerramento", "texto" => "Revisão do encerramento", "tipo" => "data",
            "nao_antes_de" => "data_encerramento" }
        ]
      }
    ]
  }.freeze

  # Nome de cada formulário de teste => estrutura
  TODOS = { "acompanhamento" => ACOMPANHAMENTO, "todos_os_tipos" => TODOS_OS_TIPOS }.freeze

  # A definição do acompanhamento, como gravada na versão publicada das fixtures
  def self.acompanhamento
    @acompanhamento ||= DefinicaoDeFormulario.new(ACOMPANHAMENTO)
  end
end
