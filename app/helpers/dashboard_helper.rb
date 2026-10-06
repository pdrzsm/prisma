module DashboardHelper
  # O que cada papel pode fazer, como nas policies (docs/seguranca.md#permissões)
  O_QUE_O_PAPEL_PODE = {
    "operador" => "consulta, registra e atualiza notificações",
    "consultor" => "consulta tudo, sem registrar nem alterar nada",
    "admin" => "consulta, registra e atualiza notificações"
  }.freeze

  # Duração em minutos, para os textos sobre login e sessão
  def em_minutos(duracao)
    pluralize(duracao.in_minutes.to_i, "minuto", plural: "minutos")
  end
end
