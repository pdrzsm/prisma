# Peças de interface usadas em várias telas. As cores vêm da paleta "marca"
# (app/assets/tailwind/application.css); o desenho está em
# docs/identidade-visual.md.
#
# As classes ficam em constantes com o texto inteiro, e não montadas aos
# pedaços: o Tailwind só gera a classe que encontra escrita no código.
module ApplicationHelper
  # --- Botões e campos -------------------------------------------------------
  # Uso: class: ApplicationHelper::BOTAO_PRIMARIO. Para mudar o tamanho, some
  # classes ("#{ApplicationHelper::CAMPO} h-12") em vez de copiar a lista.
  BOTAO_PRIMARIO = "inline-flex items-center justify-center px-5 py-2.5 bg-marca-600 hover:bg-marca-700 text-white font-semibold text-sm rounded-lg shadow-sm cursor-pointer transition"
  BOTAO_SECUNDARIO = "inline-flex items-center justify-center px-5 py-2.5 border border-marca-300 bg-white hover:bg-marca-50 text-slate-700 font-semibold text-sm rounded-lg cursor-pointer transition"
  CAMPO = "block w-full rounded-lg border border-marca-300 bg-white px-3 py-2 text-sm focus:border-marca-500 focus:outline-none focus:ring-2 focus:ring-marca-200 aria-invalid:border-rose-400"

  # --- Menu lateral (shared/_menu) -------------------------------------------
  ITEM_DO_MENU = "flex items-center py-2 pr-2 transition focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-white"
  ITEM_DO_MENU_INATIVO = "text-marca-100 hover:bg-marca-600/50 hover:text-white"
  # Página atual: fundo um pouco mais claro que a barra, de ponta a ponta
  ITEM_DO_MENU_ATIVO = "bg-marca-600 font-semibold text-white"
  private_constant :ITEM_DO_MENU, :ITEM_DO_MENU_INATIVO, :ITEM_DO_MENU_ATIVO

  # Um item do menu; o da página atual ganha destaque e aria-current="page".
  #   subitem: recuado sob o item de cima. O recuo fica no próprio item (e não
  #            na lista), para o fundo da página atual ir de ponta a ponta.
  #   icone:   classes Tailwind de um ícone em CSS, fora do texto do link.
  def item_do_menu(titulo, caminho, ativo:, subitem: false, icone: nil)
    link_to titulo, caminho, class: class_names(ITEM_DO_MENU, subitem ? "pl-8 lg:pl-7" : "pl-4",
                                                ativo ? ITEM_DO_MENU_ATIVO : ITEM_DO_MENU_INATIVO, icone),
                             aria: { current: ativo ? "page" : nil }
  end

  # --- Trilha do topo (shared/_topo) -----------------------------------------
  # Recuo de cada nível: 36 px a mais por nível, como no layout
  RECUOS_DA_TRILHA = %w[pl-0 pl-9 pl-18 pl-27].freeze
  private_constant :RECUOS_DA_TRILHA

  # Onde a pessoa está, um nível por linha, cada um recuado sob o anterior. Os
  # níveis com caminho viram link; o último, sem caminho, é a página atual.
  # Cada tela declara a sua:
  #   trilha ["Formulários", formularios_path], ["Seguimento de TB"]
  def trilha(*niveis)
    itens = niveis.each_with_index.map do |(texto, caminho), indice|
      conteudo =
        if caminho
          link_to texto, caminho, class: "hover:text-marca-700 hover:underline"
        else
          tag.span texto, class: "font-semibold text-slate-900", aria: { current: "page" }
        end
      tag.li(conteudo, class: RECUOS_DA_TRILHA.fetch(indice, RECUOS_DA_TRILHA.last))
    end

    content_for :trilha do
      tag.nav(aria: { label: "Você está em" }) do
        tag.ol(safe_join(itens), class: "mt-3 space-y-0.5 text-sm uppercase tracking-wide text-slate-700")
      end
    end
  end

  # --- Formatação ------------------------------------------------------------
  # Data e hora no formato brasileiro (06/10/2026 14:30), no fuso do sistema
  def data_e_hora(momento)
    momento&.strftime("%d/%m/%Y %H:%M")
  end

  SELO = "inline-flex whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-semibold"
  private_constant :SELO

  # Selo "Encerrada" ou "Em acompanhamento"; nada, se o formulário não tem
  # pergunta de encerramento
  def selo_da_situacao(avaliacao)
    return unless avaliacao.definicao.campo_encerramento

    if avaliacao.encerrada?
      tag.span "Encerrada", class: "#{SELO} bg-slate-100 text-slate-700"
    else
      tag.span "Em acompanhamento", class: "#{SELO} bg-emerald-50 text-emerald-700"
    end
  end
end
