# Relatórios e indicadores: a pessoa escolhe a unidade (ou todas as que vê), o
# formulário e o período. Os números vêm só das notificações que as liberações
# permitem (AvaliacaoClinicaPolicy::Scope); ver IndicadoresDoFormulario.
class RelatoriosController < ApplicationController
  include UnidadesComAcesso

  def index
    authorize :relatorios

    @unidades = unidades_com_acesso
    @bases = @unidades.values.flatten(1).map(&:first).uniq(&:chave).sort_by { |formulario| Formulario.todos.index(formulario) || 0 }
    @base = @bases.find { |formulario| formulario.chave == params[:formulario] } || @bases.first
    # "todas" ou um setor em que a pessoa consulta a base escolhida
    @unidade = @unidades.keys.find { |setor| setor.id.to_s == params[:unidade] && @unidades[setor].any? { |f, _| f == @base } }
    @meses = IndicadoresDoFormulario::PERIODOS.fetch(params[:periodo], 12)

    registros = policy_scope(AvaliacaoClinica)
    return unless @base

    registros = registros.where(formulario: @base.chave)
    registros = registros.where(setor: @unidade) if @unidade
    @indicadores = IndicadoresDoFormulario.new(registros, formulario: @base, meses: @meses)
  end
end
