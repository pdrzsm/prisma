# O rascunho de um formulário, a tela principal do gerador: o cabeçalho
# (título, finalidade, base legal...), as seções e as perguntas, com a prévia
# de como fica para quem preenche. Nada do rascunho vale para quem preenche
# até ser publicado (PublicacoesController).
module Configuracoes
  class RascunhosController < GeradorController
    before_action :carregar_rascunho, except: :create

    def show
      definicao
    end

    # Rascunho da próxima versão, com o conteúdo da publicada. Com um rascunho
    # já aberto, só leva até ele (o banco também não deixa haver dois)
    def create
      return redirect_to(no_rascunho) if @formulario.rascunho

      publicada = @formulario.versao_publicada or raise ActiveRecord::RecordNotFound
      numero = @formulario.versoes.maximum(:numero).to_i + 1
      @formulario.versoes.create!(numero:, estrutura: publicada.estrutura.deep_dup)
      redirect_to no_rascunho, notice: "Rascunho da versão #{numero} criado. A versão #{publicada.numero} continua valendo até você publicar."
    rescue ActiveRecord::RecordNotUnique
      redirect_to no_rascunho
    end

    # O cabeçalho do formulário
    def update
      @cabecalho = params.expect(cabecalho: [ :titulo, :descricao, :finalidade, :base_legal, :numeracao, :encerramento, lista: [] ]).to_h
      campos = %w[titulo descricao finalidade base_legal numeracao encerramento lista].to_h { |campo| [ campo.to_sym, @cabecalho[campo] ] }
      if edicao.atualizar_cabecalho(**campos)
        # O cabeçalho continua aberto, com o que acabou de gravar (por padrão ele fica recolhido)
        redirect_to no_rascunho("cabecalho"), notice: "Cabeçalho salvo.", flash: { cabecalho_aberto: true }
      else
        guardar_erros_e_recarregar
        definicao
        render :show, status: :unprocessable_content
      end
    end

    # Confirmação antes de descartar
    def descartar
      redirect_to excluir_configuracoes_formulario_path(@formulario) unless @formulario.publicado?
    end

    # Descarta o rascunho de um formulário publicado: a versão publicada
    # continua valendo. O que nunca foi publicado sai inteiro, pelo FormulariosController
    def destroy
      return redirect_to(excluir_configuracoes_formulario_path(@formulario), status: :see_other) unless @formulario.publicado?

      @rascunho.destroy!
      redirect_to configuracoes_formulario_path(@formulario), status: :see_other,
                                                            notice: "Rascunho descartado. A versão #{@formulario.versao_publicada.numero} continua valendo."
    end

    # Como o formulário fica para quem preenche, sem gravar nada
    def previa
      definicao
    end
  end
end
