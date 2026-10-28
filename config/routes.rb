Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  # Os registros de cada formulário (/formularios/avaliacao_nutricional/avaliacoes).
  # A página Formulários (/formularios) escolhe a unidade e, nela, a base. Só as
  # ações que existem: sem rota, o Rails não renderiza views órfãs, e registro
  # clínico não é apagado (sem destroy).
  # Relatórios e indicadores dos formulários (/relatorios)
  resources :relatorios, only: [ :index ]

  # Busca global por prontuário, em qualquer formulário e setor (o header).
  # "index" (não "show"): sem registro único pra autorizar, só o escopo —
  # ApplicationController#verify_pundit_authorization exige policy_scope só
  # no index.
  resources :buscas, only: [ :index ], path: "buscar"

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

    # Gerador de formulários (Configuracoes::FormularioPolicy). Cada formulário
    # tem um rascunho, que se edita aos poucos (seções e perguntas), e versões
    # publicadas, que nunca mudam (/configuracoes/formularios/avaliacao_nutricional/versoes/2).
    # Excluir é só para formulário que nunca foi publicado; publicada não tem
    # rota de alteração nem de exclusão. As chaves e os identificadores vêm
    # sempre no formato que o sistema gera; qualquer outro dá 404.
    chave = /[a-z][a-z0-9_]{0,63}/
    resources :formularios, only: [ :index, :new, :create, :show, :destroy ], constraints: { id: chave, formulario_id: chave } do
      get :excluir, on: :member
      # Os setores em que vale (e a instituição, enquanto não está em nenhum)
      resource :setores, only: [ :update ], controller: "setores_do_formulario"
      resource :rascunho, only: [ :show, :create, :update, :destroy ] do
        get :descartar
        get :previa
        resources :secoes, only: [ :new, :create, :edit, :update, :destroy ], constraints: { id: /s[1-9][0-9]{0,3}/ } do
          patch :mover, on: :member
        end
        resources :perguntas, only: [ :new, :create, :edit, :update, :destroy ], constraints: { id: chave } do
          get :remover, on: :member
          patch :mover, on: :member
        end
        resource :publicacao, only: [ :new, :create ]
      end
      resources :versoes, only: [ :show ], constraints: { id: /[1-9][0-9]{0,5}/ }
    end
  end

  # Troca da própria senha (obrigatória com senha temporária)
  resource :senha, only: [ :edit, :update ]

  # Modo claro ou noturno (cookie)
  resource :tema, only: [ :update ]

  # Privacidade e proteção de dados (LGPD, art. 9º), ligada no rodapé
  resource :privacidade, only: [ :show ]

  # Health check do Kamal/balanceador. Não passa pelo ApplicationController,
  # então não exige login e não expõe dados.
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "dashboard#index"
end
