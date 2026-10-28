# Registros de um formulário clínico (as notificações).
# O formulário vem da URL. A notificação nova segue a versão publicada agora;
# a que já existe, a versão em que foi registrada: é essa definição que diz
# quais respostas existem e são válidas (@definicao).
# Cada notificação é de um setor: a pessoa só vê e registra nos setores em que
# foi liberada para o formulário (AvaliacaoClinicaPolicy e Permissoes).
# Lista, detalhes e edição (inclusive a que volta sem salvar) mostram dado
# sensível: cada notificação exibida fica na auditoria de leitura
# (log_read_access, em ApplicationController).
class AvaliacoesClinicasController < ApplicationController
  POR_PAGINA = 15

  before_action :carregar_formulario
  before_action :carregar_avaliacao, only: %i[show edit update]

  def index
    authorize AvaliacaoClinica.new(formulario: @formulario.chave)
    @definicao = @formulario.definicao
    registros = policy_scope(AvaliacaoClinica).where(formulario: @formulario.chave)
    registros = registros.where(paciente_id: Paciente.ids_que_combinam(registros, params[:prontuario])) if params[:prontuario].present?

    # Filtro por setor, só entre os setores que a pessoa vê
    @setores = setores_do_formulario(permissoes.setores_que_consultam(@formulario.chave))
    @setor_filtrado = @setores.find { |setor| setor.id.to_s == params[:setor] }
    registros = registros.where(setor: @setor_filtrado) if @setor_filtrado

    # O id desempata as de mesma hora: sem ele, uma notificação podia aparecer em duas páginas, ou em nenhuma
    @paginacao = Paginacao.new(params[:pagina], por_pagina: POR_PAGINA, total: registros.count)
    @avaliacoes = registros.includes(:paciente, :user, :versao_formulario, setor: :instituicao).order(updated_at: :desc, id: :desc)
                           .limit(POR_PAGINA).offset(@paginacao.deslocamento).to_a
    @autores = AvaliacaoClinica.autores_da_ultima_alteracao(@avaliacoes)
    # Cada linha da lista mostra iniciais e prontuários: todas são lidas
    log_read_access(@avaliacoes)
    @sugestoes = Paciente.sugestoes_de_busca(@avaliacoes.map(&:paciente)) if params[:filtros].present?
  end

  def show
    authorize @avaliacao
    log_read_access(@avaliacao)
    @definicao = @avaliacao.definicao
    # Histórico da notificação, com as correções da identificação do paciente
    # feitas depois do registro dela (a correção muda o que esta tela mostra)
    correcoes = PaperTrail::Version.where(item: @avaliacao.paciente, event: "update", created_at: @avaliacao.created_at..)
    @historico = PaperTrail::Version.where(item: @avaliacao).or(correcoes).order(created_at: :desc, id: :desc).limit(20)
    @autores = User.where(id: @historico.filter_map(&:whodunnit)).index_by { |user| user.id.to_s }
  end

  def new
    authorize AvaliacaoClinica.new(formulario: @formulario.chave)
    @definicao = @formulario.definicao
    carregar_setores_para_registro
    @paciente = Paciente.new
    @avaliacao = AvaliacaoClinica.new(formulario: @formulario.chave, setor: (@setores.first if @setores.one?))
  end

  def create
    # O setor escolhido decide a permissão: autoriza antes de ler ou gravar
    # qualquer paciente (o verify_authorized só roda depois da action)
    @setor = Setor.find_by(id: params.dig(:avaliacao_clinica, :setor_id))
    @definicao = @formulario.definicao
    @avaliacao = AvaliacaoClinica.new(formulario: @formulario.chave, setor: @setor, user: current_user,
                                      versao_formulario: @formulario.versao_publicada, dados_formulario: dados_formulario_params)
    authorize @avaliacao

    # O formulário ganhou uma versão nova enquanto a pessoa preenchia: as
    # perguntas podem ter mudado, e uma resposta fora da versão nova seria
    # descartada sem aviso. A tela volta com a versão nova e o que ainda vale.
    unless params.dig(:avaliacao_clinica, :versao_formulario_id).to_s == @formulario.versao_publicada_id.to_s
      return renderizar_novo("O formulário foi atualizado enquanto você preenchia. Confira as respostas e envie de novo.")
    end

    # Paciente já cadastrado no setor é só vinculado: o formulário nunca altera cadastro
    @paciente = Paciente.identificar(setor: @setor, prontuario_sah: paciente_params[:prontuario_sah],
                                     prontuario_aghuse: paciente_params[:prontuario_aghuse],
                                     iniciais: paciente_params[:iniciais])
    paciente_existente = @paciente.present?
    @paciente ||= Paciente.new(paciente_params.merge(setor: @setor))
    @avaliacao.paciente = @paciente

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
    # A tela de edição também mostra todos os dados da notificação
    log_read_access(@avaliacao)
    @definicao = @avaliacao.definicao
  end

  def update
    authorize @avaliacao
    @definicao = @avaliacao.definicao
    @avaliacao.assign_attributes(params.require(:avaliacao_clinica).permit(:lock_version))
    @avaliacao.dados_formulario = dados_formulario_params

    if @avaliacao.save
      redirect_to formulario_avaliacao_clinica_path(@formulario, @avaliacao), notice: "Notificação atualizada."
    else
      flash.now[:alert] = "Não foi possível salvar. Revise as perguntas destacadas."
      renderizar_edicao :unprocessable_content
    end
  rescue ActiveRecord::StaleObjectError
    # Mantém o que a pessoa digitou, com a versão atual: salvar de novo
    # sobrescreve a alteração da outra pessoa conscientemente
    @avaliacao.lock_version = AvaliacaoClinica.where(id: @avaliacao.id).pick(:lock_version)
    flash.now[:alert] = "Outra pessoa salvou esta notificação enquanto você editava. Abra-a em outra aba para conferir antes de salvar de novo."
    renderizar_edicao :conflict
  end

  private

  # Só formulário publicado; o que não existe (ou nunca foi publicado) dá 404
  def carregar_formulario
    @formulario = Formulario.publicado!(params[:formulario_id])
  end

  # Notificação de outro setor (ou de outro formulário) dá 404, como se não existisse
  def carregar_avaliacao
    @avaliacao = policy_scope(AvaliacaoClinica).where(formulario: @formulario.chave).find(params[:id])
  end

  def permissoes
    current_user.permissoes
  end

  # Setores com o formulário habilitado, entre os ids dados, em ordem de nome
  def setores_do_formulario(ids)
    Setor.joins(:formularios_habilitados).where(id: ids, formularios_habilitados: { formulario: @formulario.chave })
         .includes(:instituicao).sort_by(&:nome_completo)
  end

  # Onde a pessoa pode registrar este formulário (é o que a tela oferece)
  def carregar_setores_para_registro
    @setores = setores_do_formulario(permissoes.setores_que_registram(@formulario.chave))
  end

  def renderizar_novo(mensagem)
    carregar_setores_para_registro
    # O formulário volta com o que foi digitado, nunca com o cadastro existente
    @paciente = Paciente.new(paciente_params.merge(setor: @setor)) if @paciente.nil? || @paciente.persisted?
    flash.now[:alert] = mensagem
    render :new, status: :unprocessable_content
  end

  # A edição que não foi salva volta com a identificação do paciente e os
  # dados da notificação: é uma leitura, mesmo sem passar pela action edit
  # (um PATCH inválido de propósito não pode ver os dados sem deixar rastro)
  def renderizar_edicao(status)
    log_read_access(@avaliacao)
    render :edit, status:
  end

  def paciente_params
    @paciente_params ||= params.require(:paciente).permit(:prontuario_sah, :prontuario_aghuse, :iniciais)
  end

  # Só as perguntas declaradas na versão do formulário; o model valida tipos e
  # opções. Sem respostas na requisição, um hash vazio (o fetch com padrão
  # devolveria parâmetros não permitidos, que não viram hash)
  def dados_formulario_params
    permitidos = params.fetch(:avaliacao_clinica, {}).permit(:setor_id, :versao_formulario_id,
                                                             dados_formulario: @definicao.parametros_permitidos)
    permitidos[:dados_formulario]&.to_h || {}
  end
end
