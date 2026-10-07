# Correção da identificação do paciente: prontuários e iniciais digitados
# errado (direito do titular de corrigir dados inexatos, LGPD, art. 18, III).
# A edição da notificação não mexe na identificação: corrigir é só aqui, só
# nesses três campos (o setor não muda), e vale para todas as notificações do
# paciente. Quem pode corrigir está em PacientePolicy. A correção fica no
# PaperTrail com o autor, e a tela, que mostra a identificação, na auditoria
# de leitura.
class IdentificacoesController < ApplicationController
  before_action :carregar_paciente, :carregar_notificacao

  def edit
    authorize @paciente
    log_read_access(@paciente)
  end

  def update
    authorize @paciente
    @paciente.assign_attributes(identificacao_params)
    return redirect_to destino, notice: "Nada foi alterado na identificação." unless @paciente.changed?

    if @paciente.save
      redirect_to destino, notice: "Identificação do paciente corrigida."
    else
      renderizar_edicao "Não foi possível corrigir. Revise os campos destacados."
    end
  rescue ActiveRecord::RecordNotUnique
    # Outra pessoa gravou o mesmo prontuário no setor ao mesmo tempo (índice único)
    renderizar_edicao "Esse prontuário acabou de ser cadastrado para outro paciente do setor. Confira os dados."
  end

  private

  # Paciente que a pessoa não vê dá 404, como se não existisse
  def carregar_paciente
    @paciente = policy_scope(Paciente).find(params[:paciente_id])
  end

  # A notificação de onde a pessoa veio, para voltar a ela: só entre as deste
  # paciente que ela vê (um id de outra é ignorado); sem uma válida, a mais
  # recente
  def carregar_notificacao
    notificacoes = policy_scope(AvaliacaoClinica).where(paciente: @paciente).order(updated_at: :desc, id: :desc)
    @notificacao = notificacoes.find_by(id: params[:avaliacao]) || notificacoes.first
    @formulario = Formulario.find(@notificacao.formulario)
  end

  def destino
    formulario_avaliacao_clinica_path(@formulario, @notificacao)
  end

  # A tela volta com a identificação do paciente: também é leitura
  def renderizar_edicao(mensagem)
    log_read_access(@paciente)
    flash.now[:alert] = mensagem
    render :edit, status: :unprocessable_content
  end

  # Estritamente a identificação: o setor e o resto do cadastro não mudam aqui
  def identificacao_params
    params.expect(paciente: [ :prontuario_sah, :prontuario_aghuse, :iniciais ])
  end
end
