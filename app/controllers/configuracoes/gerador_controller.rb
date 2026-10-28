# Base das telas do gerador de formulários que trabalham num formulário (o
# rascunho, as seções e perguntas dele, a publicação e as versões). Só o admin
# (Configuracoes::FormularioPolicy): a permissão é conferida antes de procurar
# o formulário, então quem não é admin não descobre nem quais chaves existem.
#
# As mudanças no rascunho passam por EdicaoDoRascunho, com o lock_version que
# veio da tela: se o rascunho mudou depois que a tela foi aberta (outra aba),
# nada é gravado e a pessoa volta ao rascunho para conferir.
module Configuracoes
  class GeradorController < ApplicationController
    before_action :carregar_formulario
    rescue_from ActiveRecord::StaleObjectError, with: :rascunho_mudou

    private

    def carregar_formulario
      authorize [ :configuracoes, Formulario ], :update?
      @formulario = Formulario.find_by!(chave: params[:formulario_id])
    end

    def carregar_rascunho
      @rascunho = @formulario.rascunho
      redirect_to configuracoes_formulario_path(@formulario), alert: "Este formulário não tem rascunho em edição." unless @rascunho
    end

    def edicao
      EdicaoDoRascunho.new(@rascunho, lock_version: params[:lock_version])
    end

    def definicao
      @definicao ||= @rascunho.definicao
    end

    def numeracao_manual?
      definicao.numeracao == "manual"
    end

    # A mudança não gravou: guarda os erros e volta o rascunho para o que está
    # no banco, para a tela ser montada com uma definição válida
    def guardar_erros_e_recarregar
      @erros = @rascunho.errors.full_messages
      @rascunho.reload
      @definicao = nil
    end

    def no_rascunho(ancora = nil)
      configuracoes_formulario_rascunho_path(@formulario, anchor: ancora)
    end

    def rascunho_mudou
      redirect_to no_rascunho, status: :see_other,
                               alert: "O rascunho mudou depois que esta tela foi aberta (em outra aba?). Confira e faça a alteração de novo."
    end
  end
end
