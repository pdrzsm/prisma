class DashboardController < ApplicationController
  def index
    authorize :dashboard
    registros = policy_scope(AvaliacaoClinica)
    @total = registros.count
    @registrados_hoje = registros.where(created_at: Time.current.all_day).count
  end
end
