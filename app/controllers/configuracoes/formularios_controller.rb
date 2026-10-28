# Configurações > Gerador de formulários, só para o admin
# (Configuracoes::FormularioPolicy): a lista dos formulários, a criação e a
# tela de cada um, com as versões. O conteúdo é editado no rascunho
# (RascunhosController). O Prisma não traz formulário nem modelo nenhum: cada
# formulário começa em branco e é montado aqui.
#
# Formulário criado começa como rascunho da versão 1 e só aparece para quem
# preenche depois de publicado. Já na criação o admin escolhe a instituição
# dele e os setores (pelo menos um) em que vai valer. Criar abre num modal por
# cima da lista (ModalHelper). Só sem notificações é excluído, publicado ou não
# (Formulario#excluivel?): com notificações, o registro clínico é preservado.
module Configuracoes
  class FormulariosController < ApplicationController
    before_action :carregar_formulario, only: [ :show, :excluir, :destroy ]

    def index
      authorize [ :configuracoes, Formulario ]
      carregar_lista
    end

    def new
      authorize [ :configuracoes, Formulario ]
      preparar_novo
    end

    def create
      authorize [ :configuracoes, Formulario ]
      dados = params.expect(formulario: [ :titulo, :instituicao_id, setor_ids: [] ])
      @titulo = dados[:titulo]
      titulo = TextoSeguro.linha(@titulo)
      # Só setores da instituição escolhida; os de outra (marcados e depois
      # escondidos pela troca de instituição na tela) são ignorados
      @instituicao = policy_scope(Instituicao).find_by(id: dados[:instituicao_id].to_s)
      @setor_ids = Array(dados[:setor_ids]).map(&:to_s)
      setores = @instituicao ? @instituicao.setores.where(id: @setor_ids).to_a : []
      erros = []
      erros << "Escolha a instituição do formulário." unless @instituicao
      erros << "Marque pelo menos um setor da instituição em que o formulário vai valer." if @instituicao && setores.empty?
      return voltar_para_novo(erros) if erros.any?

      Formulario.transaction do
        @formulario = Formulario.create!(chave: Formulario.chave_para(titulo), instituicao: @instituicao)
        @formulario.versoes.create!(numero: 1, estrutura: { "titulo" => titulo, "numeracao" => "automatica", "lista" => [], "secoes" => [] })
        setores.each { |setor| @formulario.habilitacoes.create!(setor:) }
      end
      redirect_to configuracoes_formulario_rascunho_path(@formulario),
                  notice: "Formulário criado. Monte e revise as perguntas; ele só aparece para quem preenche depois de publicado."
    rescue ActiveRecord::RecordInvalid => e
      voltar_para_novo e.record.errors.full_messages
    rescue ActiveRecord::RecordNotUnique
      # Outro formulário pegou a mesma chave no mesmo instante (índice único)
      voltar_para_novo [ "Outro formulário com o mesmo título acabou de ser criado. Envie de novo." ]
    end

    def show
      @versoes = @formulario.versoes.includes(:publicada_por).reverse
      @notificacoes_por_versao = AvaliacaoClinica.where(formulario: @formulario.chave).group(:versao_formulario_id).count
      @acompanhamento = AcompanhamentoDoFormulario.new(@formulario)
      # Os setores da instituição do formulário e, antes da regra de uma
      # instituição só, os de outra que já o tinham
      habilitados = @formulario.habilitacoes.includes(setor: :instituicao).map(&:setor)
      @setores = (@formulario.instituicao.setores.includes(:instituicao).to_a | habilitados).sort_by(&:nome_completo)
      @setores_habilitados = habilitados.map(&:id).to_set
      # Sem setores, a instituição pode ser trocada
      @instituicoes = policy_scope(Instituicao).includes(:setores).order(:nome) if habilitados.empty?
    end

    # Confirmação antes de excluir, com o que sai junto. Só formulário sem
    # notificações (publicado ou não); com notificações, a tela do formulário diz por quê.
    def excluir
      return recusar_exclusao unless @formulario.excluivel?

      authorize [ :configuracoes, @formulario ], :destroy?
      carregar_o_que_sai
    end

    def destroy
      return recusar_exclusao unless @formulario.excluivel?

      authorize [ :configuracoes, @formulario ]
      # Um formulário que já foi publicado pede a confirmação marcada na tela
      if @formulario.publicado? && params[:confirmo] != "1"
        carregar_o_que_sai
        @erros = [ "Marque a confirmação para excluir um formulário que já foi publicado." ]
        return render :excluir, status: :unprocessable_content
      end

      titulo = @formulario.titulo
      if @formulario.destroy
        redirect_to configuracoes_formularios_path, notice: "Formulário “#{titulo}” excluído. A exclusão ficou na auditoria.", status: :see_other
      else
        redirect_to configuracoes_formulario_path(@formulario), alert: @formulario.errors.full_messages.to_sentence, status: :see_other
      end
    rescue ActiveRecord::InvalidForeignKey
      # Uma notificação chegou no meio da exclusão: o banco não deixa apagar, e nada foi apagado
      redirect_to configuracoes_formulario_path(@formulario), status: :see_other,
                  alert: "Chegou uma notificação deste formulário durante a exclusão. Nada foi excluído."
    end

    private

    # Com notificações, o formulário não é excluído (registro clínico). O admin já foi autorizado a
    # ver o formulário (carregar_formulario); a tela dele explica por quê
    def recusar_exclusao
      total = helpers.pluralize(@formulario.notificacoes.count, "notificação", plural: "notificações")
      redirect_to configuracoes_formulario_path(@formulario), status: :see_other,
                  alert: "“#{@formulario.titulo}” tem #{total} e não pode ser excluído: o registro clínico é preservado."
    end

    # O que sai junto com o formulário, para a confirmação
    def carregar_o_que_sai
      @versoes = @formulario.versoes.includes(:publicada_por).to_a
      @setores_que_saem = @formulario.habilitacoes.includes(setor: :instituicao).map(&:setor).sort_by(&:nome_completo)
      @liberacoes = @formulario.liberacoes.count
    end

    # A permissão antes de procurar: quem não é admin não descobre quais chaves existem
    def carregar_formulario
      authorize [ :configuracoes, Formulario ], :show?
      @formulario = Formulario.find_by!(chave: params[:id])
    end

    def voltar_para_novo(erros)
      @erros = erros
      preparar_novo
      render :new, status: :unprocessable_content
    end

    # A lista dos formulários: a tela da lista e o fundo do modal de criação
    def carregar_lista
      @formularios = policy_scope([ :configuracoes, Formulario ]).includes(:versao_publicada, :rascunho, :instituicao)
                                                                .sort_by { |formulario| I18n.transliterate(formulario.titulo.to_s).downcase }
      @notificacoes = AvaliacaoClinica.group(:formulario).count
      @setores = FormularioHabilitado.group(:formulario).count
    end

    # O modal de criação: as instituições com os setores e a lista ao fundo
    def preparar_novo
      @instituicoes = policy_scope(Instituicao).includes(:setores).order(:nome)
      carregar_lista
    end
  end
end
