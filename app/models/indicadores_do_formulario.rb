# Indicadores de um formulário num conjunto de notificações (já filtrado pelo
# que a pessoa pode ver): volume, situação, tempo de acompanhamento, paradas e
# movimento por mês e por setor. Só números: nenhuma resposta nem dado de
# paciente sai daqui.
#
# A situação (encerrada ou não) é lida das respostas, que são cifradas, então
# a conta é feita em Ruby, com a versão do formulário de cada notificação.
class IndicadoresDoFormulario
  PERIODOS = { "3" => 3, "6" => 6, "12" => 12 }.freeze

  def initialize(registros, formulario:, meses:)
    @formulario = formulario
    @meses = meses
    @inicio = (meses - 1).months.ago.beginning_of_month
    @registros = registros.where(created_at: @inicio..).includes(:versao_formulario, setor: :instituicao).to_a
  end

  def acompanha_encerramento? = @formulario.definicao.campo_encerramento.present?

  def total = @registros.size
  def encerradas = @encerradas ||= @registros.select(&:encerrada?)
  def em_acompanhamento = @em_acompanhamento ||= @registros - encerradas

  # Em acompanhamento e sem atualização há mais de DIAS_PARADO dias
  def paradas
    @paradas ||= em_acompanhamento.count { |registro| registro.updated_at < AcompanhamentoDoFormulario::DIAS_PARADO.days.ago }
  end

  # Percentual de encerradas entre as notificações do período; nil sem registro
  def taxa_de_encerramento
    (encerradas.size * 100.0 / total).round if total.positive?
  end

  # Mediana, em dias, do registro até a última atualização das encerradas (a
  # última atualização de uma encerrada é, em geral, o encerramento)
  def mediana_de_dias
    dias = encerradas.map { |registro| (registro.updated_at - registro.created_at) / 1.day }.sort
    return if dias.empty?

    meio = dias.size / 2
    (dias.size.odd? ? dias[meio] : (dias[meio - 1] + dias[meio]) / 2).round
  end

  # [[mês (Date), registradas, encerradas], ...] em ordem, com os meses vazios
  def por_mes
    @por_mes ||= begin
      agrupados = @registros.group_by { |registro| registro.created_at.beginning_of_month.to_date }
      @meses.times.map do |passo|
        mes = (@inicio + passo.months).to_date
        grupo = agrupados.fetch(mes, [])
        [ mes, grupo.size, grupo.count { |registro| encerradas.include?(registro) } ]
      end
    end
  end

  # [[setor, registradas, em acompanhamento, paradas], ...] por nome do setor
  def por_setor
    @por_setor ||= @registros.group_by(&:setor).sort_by { |setor, _| setor.nome_completo }.map do |setor, grupo|
      abertas = grupo - encerradas
      [ setor, grupo.size, abertas.size, abertas.count { |registro| registro.updated_at < AcompanhamentoDoFormulario::DIAS_PARADO.days.ago } ]
    end
  end
end
