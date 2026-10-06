# Registros de um formulário clínico (ex.: notificações de seguimento de TB).
# O formulário vem da URL e define quais respostas existem e são válidas.
class AvaliacoesClinicasController < ApplicationController
  POR_PAGINA = 50

  before_action :carregar_formulario
  before_action :carregar_avaliacao, only: %i[show edit update]

  def index
    authorize AvaliacaoClinica
    registros = policy_scope(AvaliacaoClinica).where(formulario: @formulario.chave)
    registros = registros.where(paciente: Paciente.com_prontuario(params[:prontuario])) if params[:prontuario].present?

    @pagina = [ params[:pagina].to_i, 1 ].max
    # Um a mais que a página, só para saber se existe a próxima
    @avaliacoes = registros.includes(:paciente, :user).order(updated_at: :desc)
                           .limit(POR_PAGINA + 1).offset((@pagina - 1) * POR_PAGINA).to_a
    @tem_proxima = @avaliacoes.size > POR_PAGINA
    @avaliacoes = @avaliacoes.first(POR_PAGINA)
  end

  def show
    authorize @avaliacao
    @historico = @avaliacao.versions.reorder(created_at: :desc, id: :desc).limit(20)
    @autores = User.where(id: @historico.filter_map(&:whodunnit)).index_by { |user| user.id.to_s }
  end

  def new
    authorize AvaliacaoClinica
    @paciente = Paciente.new
    @avaliacao = AvaliacaoClinica.new(formulario: @formulario.chave)
  end

  def create
    # Antes de qualquer escrita: o verify_authorized só roda depois da action
    authorize AvaliacaoClinica

    # Paciente já cadastrado é só vinculado: o formulário nunca altera cadastro
    @paciente = Paciente.identificar(prontuario_sah: paciente_params[:prontuario_sah],
                                     prontuario_aghuse: paciente_params[:prontuario_aghuse],
                                     iniciais: paciente_params[:iniciais])
    paciente_existente = @paciente.present?
    @paciente ||= Paciente.new(paciente_params)
    @avaliacao = @paciente.avaliacoes_clinicas.build(formulario: @formulario.chave, user: current_user,
                                                     dados_formulario: dados_formulario_params)

    # Valida os dois antes de gravar, para mostrar todos os erros de uma vez
    unless [ paciente_existente || @paciente.valid?, @avaliacao.valid? ].all?
      return renderizar_novo("Não foi possível registrar. Revise as perguntas destacadas.")
    end

    AvaliacaoClinica.transaction do
      @paciente.save! unless paciente_existente
      @avaliacao.save!
    end

    aviso = "Notificação registrada."
    aviso += " Paciente já cadastrado: a identificação dele não foi alterada." if paciente_existente
    redirect_to formulario_avaliacao_clinica_path(@formulario, @avaliacao), notice: aviso
  rescue Paciente::IdentificacaoInvalida => e
    renderizar_novo e.message
  rescue ActiveRecord::RecordNotUnique
    # Outra pessoa cadastrou o mesmo prontuário ao mesmo tempo (índice único)
    renderizar_novo "Esse prontuário acabou de ser cadastrado por outra pessoa. Envie de novo para vincular a ele."
  end

  def edit
    authorize @avaliacao
  end

  def update
    authorize @avaliacao
    @avaliacao.assign_attributes(params.require(:avaliacao_clinica).permit(:lock_version))
    @avaliacao.dados_formulario = dados_formulario_params

    if @avaliacao.save
      redirect_to formulario_avaliacao_clinica_path(@formulario, @avaliacao), notice: "Notificação atualizada."
    else
      flash.now[:alert] = "Não foi possível salvar. Revise as perguntas destacadas."
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::StaleObjectError
    # Mantém o que a pessoa digitou, com a versão atual: salvar de novo
    # sobrescreve a alteração da outra pessoa conscientemente
    @avaliacao.lock_version = AvaliacaoClinica.where(id: @avaliacao.id).pick(:lock_version)
    flash.now[:alert] = "Outra pessoa salvou esta notificação enquanto você editava. Abra-a em outra aba para conferir antes de salvar de novo."
    render :edit, status: :conflict
  end

  private

  def carregar_formulario
    @formulario = Formulario.find(params[:formulario_id])
  end

  def carregar_avaliacao
    @avaliacao = policy_scope(AvaliacaoClinica).where(formulario: @formulario.chave).find(params[:id])
  end

  def renderizar_novo(mensagem)
    # O formulário volta com o que foi digitado, nunca com o cadastro existente
    @paciente = Paciente.new(paciente_params) if @paciente.nil? || @paciente.persisted?
    @avaliacao ||= AvaliacaoClinica.new(formulario: @formulario.chave, dados_formulario: dados_formulario_params)
    flash.now[:alert] = mensagem
    render :new, status: :unprocessable_content
  end

  def paciente_params
    @paciente_params ||= params.require(:paciente).permit(:prontuario_sah, :prontuario_aghuse, :iniciais)
  end

  # Só as perguntas declaradas no formulário; o model valida tipos e opções
  def dados_formulario_params
    params.fetch(:avaliacao_clinica, {}).permit(dados_formulario: @formulario.parametros_permitidos)
          .fetch(:dados_formulario, {}).to_h
  end
end
