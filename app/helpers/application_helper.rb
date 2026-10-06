module ApplicationHelper
  # Cores da paleta "marca" (app/assets/tailwind/application.css)
  BOTAO_PRIMARIO = "inline-flex items-center justify-center px-5 py-2.5 bg-marca-600 hover:bg-marca-700 text-white font-semibold text-sm rounded-lg shadow-sm cursor-pointer transition"
  BOTAO_SECUNDARIO = "inline-flex items-center justify-center px-5 py-2.5 border border-marca-300 bg-white hover:bg-marca-50 text-slate-700 font-semibold text-sm rounded-lg cursor-pointer transition"
  CAMPO = "block w-full rounded-lg border border-marca-300 bg-white px-3 py-2 text-sm focus:border-marca-500 focus:outline-none focus:ring-2 focus:ring-marca-200 aria-invalid:border-rose-400"
  ITEM_DO_MENU = "flex items-center rounded-md px-3 lg:px-2 py-2 text-white transition hover:bg-marca-600/60"

  # Item do menu lateral; o da página atual ganha destaque e aria-current.
  # icone: classes Tailwind de um ícone em CSS (fica fora do texto do link).
  def item_do_menu(titulo, caminho, ativo:, icone: nil)
    link_to titulo, caminho, class: class_names(ITEM_DO_MENU, icone, "bg-marca-600 font-semibold": ativo),
                             aria: { current: ativo ? "page" : nil }
  end

  # Trilha do topo, como no layout: um nível por linha, cada um recuado sob o
  # anterior; o último é a página atual. Uso: trilha ["Formulários", formularios_path], ["Seguimento de TB"]
  def trilha(*niveis)
    recuos = %w[pl-0 pl-9 pl-18 pl-27]
    itens = niveis.each_with_index.map do |(texto, caminho), indice|
      conteudo =
        if caminho
          link_to texto, caminho, class: "hover:text-marca-700 hover:underline"
        else
          tag.span texto, class: "font-semibold text-slate-900", aria: { current: "page" }
        end
      tag.li(conteudo, class: recuos.fetch(indice, recuos.last))
    end

    content_for :trilha do
      tag.nav(aria: { label: "Você está em" }) do
        tag.ol(safe_join(itens), class: "mt-3 space-y-0.5 text-sm uppercase tracking-wide text-slate-700")
      end
    end
  end

  def data_e_hora(momento)
    momento&.strftime("%d/%m/%Y %H:%M")
  end

  def selo_da_situacao(avaliacao)
    return unless avaliacao.definicao.campo_encerramento

    if avaliacao.encerrada?
      tag.span "Encerrada", class: "inline-flex whitespace-nowrap rounded-full bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-700"
    else
      tag.span "Em acompanhamento", class: "inline-flex whitespace-nowrap rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-700"
    end
  end
end
