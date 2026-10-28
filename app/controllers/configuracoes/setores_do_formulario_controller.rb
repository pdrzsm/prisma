# Os setores em que um formulário vale, alterados na tela dele (Configurações >
# Gerador de formulários > o formulário). Só setores da instituição do
# formulário; enquanto ele não estiver em nenhum setor, a instituição também
# pode ser trocada. Tirar de um setor tira as liberações do formulário nele, e
# um setor com notificações do formulário não sai (Formulario#habilitar_em).
module Configuracoes
  class SetoresDoFormularioController < GeradorController
    def update
      dados = params.expect(formulario: [ :instituicao_id, setor_ids: [] ])
      instituicao_id = dados[:instituicao_id].presence

      Formulario.transaction do
        if instituicao_id && instituicao_id.to_s != @formulario.instituicao_id.to_s
          @formulario.update!(instituicao: policy_scope(Instituicao).find(instituicao_id))
        end
        raise ActiveRecord::Rollback unless @formulario.habilitar_em(dados[:setor_ids])
      end

      if @formulario.errors.empty?
        redirect_to volta, notice: "Setores do formulário salvos."
      else
        redirect_to volta, alert: @formulario.errors.full_messages.to_sentence
      end
    rescue ActiveRecord::RecordInvalid
      redirect_to volta, alert: @formulario.errors.full_messages.to_sentence
    end

    private

    def volta
      configuracoes_formulario_path(@formulario, anchor: "setores")
    end
  end
end
