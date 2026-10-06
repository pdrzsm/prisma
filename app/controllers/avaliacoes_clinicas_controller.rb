class AvaliacoesClinicasController < ApplicationController
  def new
    authorize AvaliacaoClinica
    @paciente = Paciente.new
    @avaliacao_clinica = AvaliacaoClinica.new
  end

  def create
    # Antes de qualquer escrita: o verify_authorized só roda depois da action
    authorize AvaliacaoClinica

    # Paciente já cadastrado é só vinculado: este formulário nunca altera cadastro
    @paciente = Paciente.identificar(cpf: paciente_params[:cpf], prontuario_sah: paciente_params[:prontuario_sah])
    paciente_existente = @paciente.present?
    @paciente ||= Paciente.new(paciente_params)
    @avaliacao_clinica = @paciente.avaliacoes_clinicas.build(user: current_user, dados_formulario: dados_formulario_params)

    AvaliacaoClinica.transaction do
      @paciente.save! unless paciente_existente
      @avaliacao_clinica.save!
    end

    aviso = "Notificação de seguimento TB registrada com sucesso!"
    aviso += " Paciente já cadastrado: os dados cadastrais não foram alterados." if paciente_existente
    redirect_to root_path, notice: aviso
  rescue Paciente::IdentificadoresConflitantes
    renderizar_erro "CPF e prontuário SAH pertencem a pacientes diferentes. Confira os identificadores."
  rescue ActiveRecord::RecordInvalid => e
    renderizar_erro "Erro ao salvar notificação: #{e.record.errors.full_messages.to_sentence}"
  end

  private

  def renderizar_erro(mensagem)
    # O formulário volta com o que foi digitado, nunca com o cadastro existente
    @paciente = Paciente.new(paciente_params) if @paciente.nil? || @paciente.persisted?
    @avaliacao_clinica ||= AvaliacaoClinica.new
    flash.now[:alert] = mensagem
    render :new, status: :unprocessable_content
  end

  def paciente_params
    @paciente_params ||= params.require(:paciente).permit(
      :nome, :cpf, :prontuario_sah, :prontuario_aghuse, :numero_sinan,
      :municipio_residencia, :numero_contatos, :recebe_beneficio_social
    )
  end

  # Conjunto livre de campos; formato e tamanho são validados em AvaliacaoClinica
  def dados_formulario_params
    params.require(:avaliacao_clinica).permit(dados_formulario: {}).fetch(:dados_formulario, {}).to_h
  end
end
