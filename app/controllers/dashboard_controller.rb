class DashboardController < ApplicationController
  def index
    authorize :dashboard
    registros = policy_scope(AvaliacaoClinica)
    @total = registros.count
    @registrados_hoje = registros.where(created_at: Time.current.all_day).count
    @atualizados_no_mes = registros.where(updated_at: 30.days.ago..).count
  end
end
