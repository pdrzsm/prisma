class DashboardController < ApplicationController
  def index
    authorize :dashboard
    # Ainda não lista registros; ao listar, troque por policy_scope(...)
    skip_policy_scope
  end
end
