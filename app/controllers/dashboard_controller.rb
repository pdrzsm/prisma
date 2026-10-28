class DashboardController < ApplicationController
  def index
    authorize :dashboard
    # A visão geral não lista notificações, só o acesso de quem está logado
    skip_policy_scope

    # O que a pessoa pode acessar, por setor: { setor => [[formulario, papel], ...] }
    acessos = current_user.permissoes.acessos
    setores = Setor.where(id: acessos.keys.map(&:first)).includes(:instituicao).index_by(&:id)
    formularios = Formulario.todos.index_by(&:chave)
    @acessos = acessos.group_by { |(setor_id, _), _| setores[setor_id] }
                      .transform_values { |pares| pares.map { |(_, formulario), papel| [ formularios.fetch(formulario), papel ] } }
                      .sort_by { |setor, _| setor.nome_completo }
  end
end
