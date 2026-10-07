class DashboardController < ApplicationController
  def index
    authorize :dashboard
    registros = policy_scope(AvaliacaoClinica)
    @total = registros.count
    @registrados_hoje = registros.where(created_at: Time.current.all_day).count
    @atualizados_no_mes = registros.where(updated_at: 30.days.ago..).count

    # O que a pessoa pode acessar, por setor: { setor => [[formulario, papel], ...] }
    acessos = current_user.permissoes.acessos
    setores = Setor.where(id: acessos.keys.map(&:first)).includes(:instituicao).index_by(&:id)
    @acessos = acessos.group_by { |(setor_id, _), _| setores[setor_id] }
                      .transform_values { |pares| pares.map { |(_, formulario), papel| [ Formulario.find(formulario), papel ] } }
                      .sort_by { |setor, _| setor.nome_completo }
  end
end
