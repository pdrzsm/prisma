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
  #
  # Os botões têm cantos retos, como o resto do sistema (cores em botoes.css).
  BOTAO = "botao-prisma inline-flex items-center justify-center px-5 py-2 text-sm font-semibold cursor-pointer"
  BOTAO_PRIMARIO = "#{BOTAO} shadow-sm".freeze
  BOTAO_SECUNDARIO = "#{BOTAO} botao-prisma-secundario".freeze
  # Ação que apaga algo (ex.: excluir um setor): só nas telas de edição
  BOTAO_PERIGO = "#{BOTAO} botao-prisma-perigo".freeze
  CAMPO = "block w-full rounded-lg border border-marca-300 bg-white px-3 py-2 text-sm focus:border-marca-500 focus:outline-none focus:ring-2 focus:ring-marca-200 aria-invalid:border-rose-400"

  # --- Menu lateral (shared/_menu) -------------------------------------------
  # Na mesma superfície e linguagem do cabeçalho (shared/_topo): fundo claro
  # que acompanha o modo noturno, cantos retos, hover em marca-50. O item da
  # página atual ganha o fundo marca-50, o texto da marca e um filete à
  # esquerda. O recuo fica no próprio item, não na lista.
  ITEM_DO_MENU = "mx-3 flex items-center px-3 py-2 transition focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-marca-700"
  ITEM_DO_MENU_INATIVO = "text-slate-600 hover:bg-marca-50 hover:text-slate-900"
  ITEM_DO_MENU_ATIVO = "bg-marca-50 font-semibold text-marca-700 shadow-[inset_3px_0_0_var(--color-marca-600)]"
  GRUPO_DO_MENU = "mt-4 border-t border-marca-200 pt-4"
  ROTULO_DO_MENU = "px-6 pb-2 text-xs font-semibold uppercase tracking-widest text-slate-500"
  private_constant :ITEM_DO_MENU, :ITEM_DO_MENU_INATIVO, :ITEM_DO_MENU_ATIVO, :GRUPO_DO_MENU, :ROTULO_DO_MENU

  # Um item do menu; o da página atual ganha destaque e aria-current="page".
  def item_do_menu(titulo, caminho, ativo:, icone: nil)
    link_to caminho, class: class_names(ITEM_DO_MENU, ativo ? ITEM_DO_MENU_ATIVO : ITEM_DO_MENU_INATIVO),
                             aria: { current: ativo ? "page" : nil } do
      icone ? com_icone(icone, titulo, classe: "gap-3") : titulo
    end
  end

  # Um grupo do menu, abaixo de um filete: o rótulo (que não é link, para não
  # parecer uma tela) e, no bloco, os <li> com os itens.
  #   <%= grupo_do_menu "Configurações" do %> <li>...</li> <% end %>
  def grupo_do_menu(rotulo, icone: nil, &itens)
    tag.div(class: GRUPO_DO_MENU) do
      tag.p(icone ? com_icone(icone, rotulo, classe: "gap-2") : rotulo, class: ROTULO_DO_MENU) + tag.ul(capture(&itens))
    end
  end

  # --- Trilha do topo (shared/_topo) -----------------------------------------
  # Onde a pessoa está, numa linha só, no cabeçalho: os níveis separados por
  # "/", o último (a página atual) em negrito. Os níveis com caminho viram
  # link; um nível do meio sem caminho é só texto (um grupo do menu sem tela
  # própria). Antes da trilha, o cabeçalho põe a seta de voltar ao nível de
  # cima que tem caminho (nas telas de primeiro nível, não aparece): um link
  # comum, que não depende do histórico do navegador. Cada tela declara a sua:
  #   trilha ["Formulários"], [@formulario.titulo, formulario_avaliacoes_clinicas_path(@formulario)], ["Nova notificação"]
  #
  # A trilha nunca quebra de linha: o cabeçalho tem sempre a altura da faixa do
  # logo na barra lateral (as duas linhas se encontram), e os avisos e as
  # âncoras da página contam com ela. Pela largura que a trilha tem (container
  # query, só CSS), os níveis somem do começo para o fim, e a página atual fica
  # sempre. Cada nível só aparece quando a trilha tem a largura de que ele e os
  # que vêm depois precisam, estimada pelo tamanho dos textos e arredondada
  # para cima, de 4 em 4 rem. As classes ficam escritas por inteiro, que é o
  # que o Tailwind precisa para gerá-las.
  NIVEIS_QUE_CABEM = {
    12 => "hidden @min-[12rem]:flex", 16 => "hidden @min-[16rem]:flex", 20 => "hidden @min-[20rem]:flex", 24 => "hidden @min-[24rem]:flex",
    28 => "hidden @min-[28rem]:flex", 32 => "hidden @min-[32rem]:flex", 36 => "hidden @min-[36rem]:flex", 40 => "hidden @min-[40rem]:flex",
    44 => "hidden @min-[44rem]:flex", 48 => "hidden @min-[48rem]:flex", 52 => "hidden @min-[52rem]:flex", 56 => "hidden @min-[56rem]:flex",
    60 => "hidden @min-[60rem]:flex", 64 => "hidden @min-[64rem]:flex", 68 => "hidden @min-[68rem]:flex", 72 => "hidden @min-[72rem]:flex"
  }.freeze
  REM_POR_LETRA_DA_TRILHA = 0.55 # texto em negrito de 14 px, com folga
  REM_POR_SEPARADOR_DA_TRILHA = 1.6
  private_constant :NIVEIS_QUE_CABEM, :REM_POR_LETRA_DA_TRILHA, :REM_POR_SEPARADOR_DA_TRILHA

  def trilha(*niveis)
    ultimo = niveis.size - 1
    barra = tag.span("/", class: "text-slate-400", aria: { hidden: true })
    itens = niveis.each_with_index.map do |(texto, caminho), indice|
      conteudo =
        if caminho
          link_to texto, caminho, class: "truncate hover:text-marca-700 hover:underline"
        elsif indice == ultimo
          tag.span texto, class: "truncate font-semibold text-slate-900", aria: { current: "page" }
        else
          tag.span texto, class: "truncate"
        end
      # A barra vai depois do nível, não antes do seguinte
      separador = indice == ultimo ? "".html_safe : barra
      # A página atual está sempre à vista; os outros níveis, quando cabem junto com os de depois
      aparece =
        if indice == ultimo
          "flex"
        else
          precisa = niveis[indice..].sum { |nivel, _| nivel.to_s.length * REM_POR_LETRA_DA_TRILHA } + (ultimo - indice) * REM_POR_SEPARADOR_DA_TRILHA
          NIVEIS_QUE_CABEM.fetch((precisa / 4.0).ceil.clamp(3, 18) * 4)
        end
      tag.li(safe_join([ conteudo, separador ]), class: class_names(aparece, "min-w-0 items-center gap-2", "max-w-full shrink-0": indice == ultimo))
    end

    texto_pai, caminho_pai = niveis[0...-1].reverse.find { |_, caminho| caminho }
    if caminho_pai
      content_for(:voltar_caminho) { caminho_pai }
      content_for(:voltar_texto) { texto_pai }
    end

    content_for :trilha do
      tag.nav(aria: { label: "Você está em" }, class: "@container min-w-0 flex-1") do
        tag.ol(safe_join(itens), class: "flex min-w-0 flex-nowrap items-center gap-x-2 overflow-hidden text-sm text-slate-600")
      end
    end
  end

  # --- Formatação ------------------------------------------------------------
  # Data e hora no formato brasileiro (06/10/2026 14:30), no fuso do sistema
  def data_e_hora(momento)
    momento&.strftime("%d/%m/%Y %H:%M")
  end

  SELO = "inline-flex whitespace-nowrap px-2 py-0.5 text-xs font-semibold"
  private_constant :SELO

  # Selo "Encerrada" ou "Em acompanhamento", com ícone; nada, se o formulário não tem
  # pergunta de encerramento
  def selo_da_situacao(avaliacao)
    return unless avaliacao.definicao.campo_encerramento

    if avaliacao.encerrada?
      tag.span com_icone(:ok, "Encerrada"), class: "#{SELO} bg-slate-100 text-slate-700"
    else
      tag.span com_icone(:ponto, "Em acompanhamento"), class: "#{SELO} bg-emerald-50 text-emerald-700"
    end
  end
end
