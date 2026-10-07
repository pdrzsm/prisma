Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  # Seção "Formulários" e os registros de cada formulário (/formularios/seguimento_tb/avaliacoes).
  # Só as ações que existem: sem rota, o Rails não renderiza views órfãs, e
  # registro clínico não é apagado (sem destroy).
  resources :formularios, only: [ :index ] do
    resources :avaliacoes_clinicas, path: "avaliacoes", only: [ :index, :show, :new, :create, :edit, :update ],
                                    constraints: { formulario_id: /[a-z0-9_]+/ }
  end

  # Correção da identificação do paciente (prontuários e iniciais), aberta a
  # partir de uma notificação: /pacientes/7/identificacao/edit?avaliacao=12.
  # Paciente não tem lista nem tela própria: aparece pelas notificações.
  resources :pacientes, only: [] do
    resource :identificacao, only: [ :edit, :update ]
  end

  # Configurações, só para o admin (ConfiguracaoPolicy): as instituições e,
  # dentro de cada uma, os setores (/configuracoes/instituicoes/1/setores/new).
  # A lista das instituições já mostra os setores, por isso não há index nem
  # show de setor, nem show de instituição.
  namespace :configuracoes do
    resources :instituicoes, except: [ :show ] do
      resources :setores, except: [ :index, :show ]
    end
    # Usuários não são excluídos (desativa-se). Cada um tem as suas liberações
    # e a senha temporária que o admin define (/configuracoes/usuarios/3/senha/edit).
    resources :usuarios, except: [ :show, :destroy ] do
      resource :liberacoes, only: [ :edit, :update ]
      resource :senha, only: [ :edit, :update ], controller: "senhas_temporarias"
    end
  end

  # Troca da própria senha (obrigatória com senha temporária)
  resource :senha, only: [ :edit, :update ]

  # Health check do Kamal/balanceador. Não passa pelo ApplicationController,
  # então não exige login e não expõe dados.
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "dashboard#index"
end
