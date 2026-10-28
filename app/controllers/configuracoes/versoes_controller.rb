# Uma versão publicada de um formulário, só para consulta: como ela é, quem a
# publicou e quando, e quantas notificações a seguem. Não há rota para alterar
# nem excluir uma versão publicada.
module Configuracoes
  class VersoesController < GeradorController
    def show
      @versao = @formulario.versoes.publicadas.includes(:publicada_por).find_by!(numero: params[:id])
      @definicao = @versao.definicao
      @notificacoes = @versao.avaliacoes_clinicas.count
    end
  end
end
