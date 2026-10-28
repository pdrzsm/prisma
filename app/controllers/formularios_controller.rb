# Formulários: a pessoa escolhe a unidade (o setor) e, dentro dela, a base (o
# formulário) a que tem acesso, em dois menus suspensos encadeados; embaixo, a
# planilha com os registros daquela base naquela unidade, como em "Ver
# registros". Só mostra o que as liberações permitem (Permissoes e
# AvaliacaoClinicaPolicy). Cada notificação exibida fica na auditoria de leitura.
class FormulariosController < ApplicationController
  include UnidadesComAcesso

  # Notificações por página (a lista de cada formulário, em
  # AvaliacoesClinicasController, tem o próprio tamanho)
  LIMITE = 14

  def index
    authorize :formularios

    @unidades = unidades_com_acesso
    @unidade = @unidades.keys.find { |setor| setor.id.to_s == params[:unidade] } || @unidades.keys.first
    @bases = @unidade ? @unidades.fetch(@unidade) : []
    @base, @papel = @bases.find { |formulario, _| formulario.chave == params[:formulario] } || @bases.first

    @avaliacoes = carregar_registros
    @autores = AvaliacaoClinica.autores_da_ultima_alteracao(@avaliacoes)
    log_read_access(@avaliacoes)
    @sugestoes = Paciente.sugestoes_de_busca(@avaliacoes.map(&:paciente)) if params[:filtros].present?
  end

  private

  # Uma página (LIMITE) dos registros mais recentes da base escolhida, na unidade escolhida (e com o
  # prontuário do filtro, se houver). Deixa a posição na lista em @paginacao.
  def carregar_registros
    registros = policy_scope(AvaliacaoClinica)
    @paginacao = Paginacao.new(params[:pagina], por_pagina: LIMITE, total: 0)
    return [] unless @base

    registros = registros.where(formulario: @base.chave, setor: @unidade)
    registros = registros.where(paciente_id: Paciente.ids_que_combinam(registros, params[:prontuario])) if params[:prontuario].present?
    @paginacao = Paginacao.new(params[:pagina], por_pagina: LIMITE, total: registros.count)
    # O id desempata as de mesma hora: sem ele, uma notificação podia aparecer em duas páginas, ou em nenhuma
    registros.includes(:paciente, :user, :versao_formulario, setor: :instituicao)
             .order(updated_at: :desc, id: :desc).limit(LIMITE).offset(@paginacao.deslocamento).to_a
  end
end
