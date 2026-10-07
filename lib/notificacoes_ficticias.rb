# Notificações fictícias de seguimento de TB para ver o sistema com dados em
# desenvolvimento (bin/rails dev:notificacoes). Cada uma é gravada pelo model,
# com validação, criptografia e auditoria, como se tivesse sido digitada na
# tela: aberta numa data, atualizada mês a mês e, parte delas, encerrada.
#
# Nada aqui é de paciente real: os prontuários começam com TESTE- e os
# municípios são inventados. A mesma semente gera sempre os mesmos dados, e
# rodar de novo não duplica (o prontuário identifica cada notificação no setor).
# Tudo vai para um setor, com o formulário habilitado nele.
class NotificacoesFicticias
  FORMULARIO = "seguimento_tb".freeze
  MUNICIPIOS = [ "Cidade Fictícia", "Vila Exemplo", "Porto Modelo", "Campo Simulado", "Serra de Teste", "Lagoa Imaginária" ].freeze
  # Desfechos sorteados, com peso: cura é o mais comum
  DESFECHOS = { "1" => 70, "2" => 10, "3" => 3, "4" => 4, "5" => 8, "6" => 5 }.freeze
  # Desfechos que encerram antes dos 6 meses de tratamento
  INTERROMPIDOS = %w[2 3 4 5 6].freeze
  # Local da TB extrapulmonar -> material examinado (pergunta 26)
  MATERIAL_DO_LOCAL = { "1" => "3", "2" => "2", "3" => "6", "4" => "7", "7" => "1", "8" => "8" }.freeze

  def initialize(quantidade:, autores:, setor:, semente: 2026, hoje: Date.current)
    raise "Notificações fictícias não são geradas em produção." if Rails.env.production?

    @quantidade = quantidade
    @autores = autores
    @setor = setor
    @hoje = hoje
    @sorteio = Random.new(semente)
  end

  # Cria as notificações que ainda não existem e devolve quantas criou
  def gerar
    (1..@quantidade).count do |numero|
      # Sorteia sempre, mesmo se já existir, para a sequência não mudar
      etapas = planejar
      prontuario_sah = format("TESTE-SAH-%04d", numero)
      prontuario_aghuse = format("TESTE-AGH-%04d", numero) if @sorteio.rand < 0.6
      iniciais = Array.new(@sorteio.rand(2..4)) { ("A".."Z").to_a.sample(random: @sorteio) }.join
      autor = @autores.sample(random: @sorteio)
      next false if Paciente.exists?(setor: @setor, prontuario_sah:)

      gravar(etapas, autor, prontuario_sah:, prontuario_aghuse:, iniciais:)
      true
    end
  end

  private

  # A primeira etapa cria a notificação; as outras são as atualizações, cada
  # uma com o seu horário (e a sua versão na auditoria)
  def gravar(etapas, autor, **identificacao)
    (momento, respostas), *atualizacoes = etapas
    ActiveRecord::Base.transaction do
      PaperTrail.request(whodunnit: autor.id.to_s) do
        paciente = Paciente.create!(**identificacao, setor: @setor, created_at: momento, updated_at: momento)
        avaliacao = AvaliacaoClinica.create!(paciente:, setor: @setor, user: autor, formulario: FORMULARIO,
                                             dados_formulario: respostas, created_at: momento, updated_at: momento)
        atualizacoes.each do |momento_da_etapa, novas|
          avaliacao.update!(dados_formulario: avaliacao.respostas.merge(novas), updated_at: momento_da_etapa)
        end
      end
    end
  end

  # Etapas [momento, respostas]: abertura, um registro por mês de exames e,
  # se for o caso, o encerramento
  def planejar
    inicio = @hoje - @sorteio.rand(0..420)
    decorridos = (@hoje - inicio).to_i
    caso = sortear_caso
    encerramento = sortear_encerramento(inicio, decorridos, caso)

    meses = (1..6).map { |mes| [ mes, inicio + (30 * mes) + @sorteio.rand(0..5) ] }
                  .select { |_, data| encerramento ? data < encerramento : data <= @hoje }
    etapas = [ [ horario(inicio), abertura(caso) ] ]
    meses.each { |mes, data| etapas << [ horario(data), exames_do_mes(mes, caso) ] }
    etapas << [ horario(encerramento), fechamento(caso, encerramento, meses.size) ] if encerramento
    etapas
  end

  # Horário de expediente naquele dia, nunca depois de agora
  def horario(data)
    [ Time.zone.local(data.year, data.month, data.day, @sorteio.rand(8..17), @sorteio.rand(60)), Time.current ].min
  end

  # Sorteio com peso: pesado("1" => 70, "2" => 30) dá "1" em 70% das vezes
  def pesado(pesos)
    alvo = @sorteio.rand(pesos.values.sum)
    pesos.each do |valor, peso|
      return valor if alvo < peso

      alvo -= peso
    end
  end

  def sortear_caso
    forma = pesado("1" => 65, "2" => 20, "3" => 15)
    locais = forma == "1" ? [] : %w[1 2 3 4 5 6 7 8 9 10].sample(@sorteio.rand(1..2), random: @sorteio).sort_by(&:to_i)
    resistente = forma != "2" && @sorteio.rand < 0.06
    { forma:, locais:, resistente:, pulmonar: forma != "2", hiv: @sorteio.rand < 0.12,
      desfecho: resistente ? "7" : pesado(DESFECHOS) }
  end

  # Com mais de ~7 meses de tratamento, a maioria já está encerrada; antes
  # disso, só as interrompidas (abandono, óbito, transferência...)
  def sortear_encerramento(inicio, decorridos, caso)
    interrompido = INTERROMPIDOS.include?(caso[:desfecho])
    if decorridos >= 200 && @sorteio.rand < 0.8
      interrompido ? inicio + @sorteio.rand(45..170) : inicio + @sorteio.rand(180..[ 270, decorridos ].min)
    elsif decorridos >= 60 && interrompido && @sorteio.rand < 0.3
      inicio + @sorteio.rand(45..[ 170, decorridos ].min)
    end
  end

  def abertura(caso)
    respostas = {
      "numero_sinan" => format("%07d", @sorteio.rand(10_000_000)),
      "gestante" => pesado("6" => 60, "5" => 35, "2" => 3, "4" => 2),
      "populacoes_especiais" => @sorteio.rand < 0.8 ? [ "0" ] : [ %w[1 2 3 4 5].sample(random: @sorteio) ],
      "recebe_beneficio" => pesado("0" => 60, "1" => 30, "2" => 10),
      "municipio_residencia" => MUNICIPIOS.sample(random: @sorteio),
      "forma_clinica" => caso[:forma],
      "rx_torax" => caso[:pulmonar] ? pesado("1" => 85, "3" => 15) : pesado("2" => 50, "4" => 30, "1" => 20)
    }
    respostas["tb_extrapulmonar"] = caso[:locais] if caso[:locais].any?
    respostas["tomografia"] = [ pesado("1" => 60, "2" => 20, "3" => 20) ] if @sorteio.rand < 0.3
    respostas["tratamento_diretamente_observado"] = pesado("1" => 60, "0" => 40) if @sorteio.rand < 0.7
    respostas["comorbidades"] = comorbidades if @sorteio.rand < 0.7
    respostas["doencas_oportunistas"] = caso[:hiv] ? [ pesado("5" => 40, "2" => 20, "0" => 40) ] : [ "0" ] if caso[:hiv] || @sorteio.rand < 0.4
    respostas.merge(material_examinado(caso))
  end

  # Na extrapulmonar, o material do local é examinado no diagnóstico
  def material_examinado(caso)
    return {} if caso[:locais].empty?

    respostas = {
      "outro_material" => MATERIAL_DO_LOCAL.fetch(caso[:locais].first, "9"),
      "baciloscopia_outro_material" => pesado("2" => 50, "1" => 25, "3" => 25),
      "trm_outro_material" => pesado("1" => 45, "3" => 35, "5" => 20),
      "histopatologico" => pesado("2" => 50, "1" => 25, "5" => 25)
    }
    respostas["cultura_outro_material"] = pesado("5" => 50, "6" => 30, "7" => 20) if @sorteio.rand < 0.5
    respostas
  end

  def comorbidades
    return [ "0" ] if @sorteio.rand < 0.5

    %w[1 2 3 4 5 6 7].sample(@sorteio.rand(1..2), random: @sorteio).sort
  end

  def exames_do_mes(mes, caso)
    { "baciloscopia_escarro_mes_#{mes}" => baciloscopia(mes, caso), "trm_escarro_mes_#{mes}" => trm(mes, caso) }
  end

  def baciloscopia(mes, caso)
    return pesado("4" => 70, "3" => 30) unless caso[:pulmonar]

    case mes
    when 1 then pesado("1" => 60, "2" => 35, "3" => 5)
    when 2 then pesado("1" => 20, "2" => 70, "3" => 10)
    else pesado("2" => 85, "3" => 15)
    end
  end

  # TRM-TB é feito no diagnóstico; no seguimento, em geral não é repetido
  def trm(mes, caso)
    return "5" unless caso[:pulmonar]
    return "2" if mes == 1 && caso[:resistente]
    return pesado("1" => 85, "3" => 10, "4" => 5) if mes == 1

    pesado("5" => 90, "3" => 10)
  end

  # Tudo o que o encerramento exige e ainda não foi respondido
  def fechamento(caso, encerramento, meses_com_exame)
    respostas = {}
    (meses_com_exame + 1..6).each do |mes|
      # Meses sem registro (tratamento interrompido): exames não realizados
      respostas["baciloscopia_escarro_mes_#{mes}"] = caso[:pulmonar] ? "3" : "4"
      respostas["trm_escarro_mes_#{mes}"] = "5"
    end
    respostas.merge!(
      "baciloscopia_escarro_apos_6_meses" => caso[:pulmonar] ? pesado("2" => 40, "3" => 60) : "4",
      "trm_escarro_apos_6_meses" => "5",
      "mudanca_esquema" => (caso[:resistente] || @sorteio.rand < 0.08) ? "1" : "0",
      "desfecho" => caso[:desfecho],
      "data_encerramento" => encerramento.iso8601
    )
    respostas.merge!("outro_material" => "0", "baciloscopia_outro_material" => "4", "trm_outro_material" => "5", "histopatologico" => "5") if caso[:locais].empty?
    respostas["cultura_escarro"] = caso[:resistente] ? "2" : pesado("5" => 60, "7" => 40) if caso[:pulmonar] && @sorteio.rand < 0.5
    respostas["motivo_mudanca_esquema"] = caso[:resistente] ? "Resistência à rifampicina no TRM-TB." : "Efeito adverso aos medicamentos." if respostas["mudanca_esquema"] == "1"
    respostas["motivo_mudanca_diagnostico"] = pesado("1" => 40, "2" => 20, "3" => 40) if caso[:desfecho] == "6"
    if caso[:hiv]
      respostas["cd4_final_tratamento"] = @sorteio.rand(80..900)
      respostas["carga_viral_final_tratamento"] = @sorteio.rand < 0.6 ? "indetectável" : @sorteio.rand(50..20_000).to_s
    end
    contatos = @sorteio.rand(0..8)
    respostas.merge!("numero_contatos" => contatos, "numero_contatos_avaliados" => @sorteio.rand(0..contatos))
    revisao = encerramento + @sorteio.rand(1..20)
    respostas["data_revisao_encerramento"] = revisao.iso8601 if revisao <= @hoje && @sorteio.rand < 0.3
    respostas
  end
end
