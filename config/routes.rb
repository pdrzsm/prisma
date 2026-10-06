Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  # Apenas as ações implementadas. Sem rota, o Rails não renderiza views
  # órfãs (ex.: show.html.erb) de forma implícita.
  resources :avaliacoes_clinicas, only: [ :new, :create ]

  # Health check do Kamal/balanceador. Não passa pelo ApplicationController,
  # então não exige login e não expõe dados.
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "dashboard#index"
end
