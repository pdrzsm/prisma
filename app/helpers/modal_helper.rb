# Telas curtas (cadastrar, editar, definir senha, uma pergunta ou seção do
# gerador) numa janela no centro da tela, por cima da lista ou do rascunho de
# onde vieram. A URL continua a de sempre (/new, /edit): a tela
# desenha a lista ao fundo e o conteúdo num <dialog open> na frente. Assim o
# "voltar" do navegador, os links diretos e a validação (que redesenha a mesma
# tela com os erros) funcionam como antes.
#
# Sem JavaScript: o layout põe inert no resto da página (não recebe clique nem
# foco, e o leitor de tela não a lê) e o foco começa no modal (autofocus).
# Fechar é um link de volta para a lista, e não um fechamento só no navegador,
# que deixaria a página de fundo inerte. Desenho em modal.css e em
# docs/identidade-visual.md ("Modais").
module ModalHelper
  # Uso, no lugar do conteúdo da tela:
  #   <%= render "lista" %>
  #   <% modal "Novo setor", fechar: configuracoes_instituicoes_path, descricao: "Em Centro X." do %>
  #     <%= render "formulario", setor: @setor %>
  #   <% end %>
  #
  # A janela tem a altura do conteúdo, no meio da tela; se não cabe, o corpo
  # rola por dentro, e o cabeçalho (título e X) fica parado. largura é a classe
  # do Tailwind da largura máxima ("max-w-xl" por padrão): escrita por inteiro
  # na chamada, que é o que o Tailwind precisa para gerá-la.
  #
  # Com rodape: true, o bloco traz o próprio formulário, com o corpo que rola e
  # o rodapé das ações sempre à vista (PAINEL_FORMULARIO, PAINEL_CORPO e
  # PAINEL_RODAPE, como no painel lateral). É o caso dos formulários longos,
  # como o da pergunta do gerador, em que o botão de salvar não pode ficar lá
  # embaixo, no fim da rolagem.
  def modal(titulo, fechar:, descricao: nil, rodape: false, largura: "max-w-xl", &conteudo)
    content_for :modal do
      tag.dialog(open: true, tabindex: -1, autofocus: true,
                 class: "modal fixed inset-0 z-40 m-0 flex h-full max-h-none w-full max-w-none items-center justify-center " \
                        "border-0 bg-black/40 p-4 text-slate-800 focus:outline-none",
                 aria: { modal: true, labelledby: "modal_titulo", describedby: ("modal_descricao" if descricao) }.compact) do
        tag.section(class: "flex max-h-full w-full #{largura} flex-col border border-marca-200 bg-white shadow-xl") do
          corpo = rodape ? "flex min-h-0 flex-1 flex-col" : "min-h-0 flex-1 space-y-6 overflow-y-auto overscroll-contain px-5 py-5"
          cabecalho_do_modal(titulo, descricao, fechar) + tag.div(capture(&conteudo), class: corpo)
        end
      end
    end
  end

  # Painel lateral (filtros, opções de uma lista), no desenho do painel do SGA:
  # entra pela direita, deixa o resto da tela à vista atrás do véu e tem
  # cabeçalho (ícone e título em caixa alta, e o X), corpo que rola e rodapé
  # com as ações. Mesma técnica do modal: <dialog open> na URL de sempre
  # (?filtros=1), fundo inerte e um link de volta para fechar, sem JavaScript.
  # O bloco recebe o corpo e o rodapé, dentro de um <form> ou não:
  #   <% painel_lateral "Filtros", fechar: lista_path, simbolo: :filtro do %>
  #     <%= form_with ..., class: ModalHelper::PAINEL_FORMULARIO do |f| %>
  #       <div class="<%= ModalHelper::PAINEL_CORPO %>">campos</div>
  #       <div class="<%= ModalHelper::PAINEL_RODAPE %>">ações</div>
  #     <% end %>
  #   <% end %>
  PAINEL_FORMULARIO = "flex min-h-0 flex-1 flex-col"
  PAINEL_CORPO = "min-h-0 flex-1 space-y-5 overflow-y-auto overscroll-contain px-5 py-5"
  PAINEL_RODAPE = "flex shrink-0 items-center justify-end gap-3 border-t border-marca-200 px-5 py-3"

  def painel_lateral(titulo, fechar:, simbolo: nil, &conteudo)
    content_for :modal do
      tag.dialog(open: true, tabindex: -1, autofocus: true,
                 class: "modal fixed inset-0 z-40 m-0 flex h-full max-h-none w-full max-w-none border-0 bg-black/40 p-0 " \
                        "text-slate-800 focus:outline-none",
                 aria: { modal: true, label: titulo }) do
        tag.aside(class: "ml-auto flex h-full w-full max-w-md flex-col border-l border-marca-200 bg-white shadow-xl") do
          cabecalho = tag.div(class: "flex shrink-0 items-center justify-between gap-4 border-b border-marca-200 px-5 py-3") do
            tag.p(class: "flex items-center gap-2 text-xs font-bold uppercase tracking-widest text-slate-600") do
              (simbolo ? icone(simbolo) : "".html_safe) + titulo
            end + link_to(fechar, aria: { label: "Fechar" }, title: "Fechar",
                                  class: "flex h-9 w-9 shrink-0 items-center justify-center border border-marca-300 text-slate-600 " \
                                         "hover:bg-marca-50 focus-visible:outline-2 focus-visible:outline-marca-700") { icone(:fechar, classe: "h-4 w-4") }
          end
          cabecalho + capture(&conteudo)
        end
      end
    end
  end

  # Janela no centro da tela, para confirmar uma ação curta (a troca da
  # própria senha). Mesma técnica do modal: <dialog open>, fundo inerte e um
  # link de volta para fechar, sem JavaScript. O bloco recebe o corpo e o
  # rodapé, como no painel lateral (PAINEL_FORMULARIO, PAINEL_CORPO,
  # PAINEL_RODAPE).
  def janela(titulo, fechar:, simbolo: nil, &conteudo)
    content_for :modal do
      tag.dialog(open: true, tabindex: -1, autofocus: true,
                 class: "modal fixed inset-0 z-40 m-0 flex h-full max-h-none w-full max-w-none items-center justify-center " \
                        "border-0 bg-black/40 p-4 text-slate-800 focus:outline-none",
                 aria: { modal: true, label: titulo }) do
        tag.section(class: "flex max-h-full w-full max-w-md flex-col border border-marca-200 bg-white shadow-xl") do
          cabecalho = tag.div(class: "flex shrink-0 items-center justify-between gap-4 border-b border-marca-200 px-5 py-3") do
            tag.h2(class: "flex items-center gap-2 text-sm font-bold uppercase tracking-widest text-slate-700") do
              (simbolo ? icone(simbolo) : "".html_safe) + titulo
            end + link_to(fechar, aria: { label: "Fechar" }, title: "Fechar",
                                  class: "flex h-9 w-9 shrink-0 items-center justify-center border border-marca-300 text-slate-600 " \
                                         "hover:bg-marca-50 focus-visible:outline-2 focus-visible:outline-marca-700") { icone(:fechar, classe: "h-4 w-4") }
          end
          cabecalho + capture(&conteudo)
        end
      end
    end
  end

  private

  def cabecalho_do_modal(titulo, descricao, fechar)
    tag.div(class: "flex shrink-0 items-start justify-between gap-4 border-b border-marca-200 px-5 py-4") do
      textos = tag.div(class: "min-w-0") do
        safe_join([ tag.h1(titulo, id: "modal_titulo", class: "text-xl font-bold text-slate-900"),
                    (tag.p(descricao, id: "modal_descricao", class: "text-sm text-slate-600") if descricao) ].compact)
      end
      textos + link_to(fechar, aria: { label: "Fechar" }, title: "Fechar",
                               class: "flex h-9 w-9 shrink-0 items-center justify-center border border-marca-300 text-slate-600 " \
                                      "hover:bg-marca-50 focus-visible:outline-2 focus-visible:outline-marca-700") { icone(:fechar, classe: "h-4 w-4") }
    end
  end

  # Janela aberta por ?painel= em qualquer tela, a partir do menu da conta no
  # cabeçalho (shared/_topo). Chamado pelo layout, só se a tela não abriu um
  # modal própria. Novidades, avisos e a conta são menus suspensos do próprio
  # cabeçalho; só a troca de senha abre aqui, no centro da tela.
  def painel_do_topo
    return unless params[:painel] == "senha"

    caminho_de_volta = request.path + (request.query_parameters.except("painel").then { |q| q.any? ? "?#{q.to_query}" : "" })
    janela("Trocar senha", fechar: caminho_de_volta, simbolo: :chave) do
      render "senhas/janela", fechar: caminho_de_volta
    end
  end
end
