Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  # Seção "Formulários" e os registros de cada formulário (/formularios/seguimento_tb/avaliacoes).
  # Só as ações que existem: sem rota, o Rails não renderiza views órfãs, e
  # registro clínico não é apagado (sem destroy).
  resources :formularios, only: [ :index ] do
    resources :avaliacoes_clinicas, path: "avaliacoes", only: [ :index, :show, :new, :create, :edit, :update ],
                                    constraints: { formulario_id: /[a-z0-9_]+/ }
  end

  # Configurações, só para o admin (ConfiguracaoPolicy): as instituições e,
  # dentro de cada uma, os setores (/configuracoes/instituicoes/1/setores/new).
  # A lista das instituições já mostra os setores, por isso não há index nem
  # show de setor, nem show de instituição.
  namespace :configuracoes do
    resources :instituicoes, except: [ :show ] do
      resources :setores, except: [ :index, :show ]
    end
  end

  # Health check do Kamal/balanceador. Não passa pelo ApplicationController,
  # então não exige login e não expõe dados.
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "dashboard#index"
end
