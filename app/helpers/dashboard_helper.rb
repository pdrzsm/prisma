module DashboardHelper
  # O que cada papel pode fazer, como nas policies (docs/seguranca.md#permissões)
  O_QUE_O_PAPEL_PODE = {
    "admin" => "A conta única do sistema. Administra formulários, usuários, instituições, setores e liberações, consulta as notificações de todos os setores e registra onde o formulário está habilitado.",
    "usuario" => "Usa só o que o admin liberou: cada formulário, em cada setor, para apenas consultar ou também registrar. Não vê as Configurações."
  }.freeze

  # Como o papel aparece na tela
  NOME_DO_PAPEL = { "admin" => "Admin", "usuario" => "Usuário" }.freeze

  # Duração em minutos, para os textos sobre login e sessão
  def em_minutos(duracao)
    pluralize(duracao.in_minutes.to_i, "minuto", plural: "minutos")
  end
end
