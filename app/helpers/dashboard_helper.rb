module DashboardHelper
  # O que cada papel pode fazer, como nas policies (docs/seguranca.md#permissões)
  O_QUE_O_PAPEL_PODE = {
    "admin" => "a conta única que administra o sistema (usuários, instituições, setores e liberações) e vê e registra tudo",
    "usuario" => "vê e registra só o que o admin liberar: em cada setor, cada formulário, para consultar ou registrar"
  }.freeze

  # Como o papel aparece na tela
  NOME_DO_PAPEL = { "admin" => "Admin", "usuario" => "Usuário" }.freeze

  # Duração em minutos, para os textos sobre login e sessão
  def em_minutos(duracao)
    pluralize(duracao.in_minutes.to_i, "minuto", plural: "minutos")
  end
end
