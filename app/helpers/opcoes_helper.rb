# Grupos e linhas das telas de Configurações, no jeito das Configurações do
# GNOME: cada grupo tem um título e, embaixo, um cartão com as linhas,
# separadas por filetes; cada linha tem título, subtítulo e, à direita, o
# controle (interruptor, segmentos ou a seta de um link). Desenho e regras em
# docs/identidade-visual.md ("Configurações: grupos e linhas").
#
# Como em ApplicationHelper, as classes ficam em constantes com o texto
# inteiro: o Tailwind só gera a classe que encontra escrita no código.
module OpcoesHelper
  CARTAO = "divide-y divide-marca-100 overflow-hidden rounded-xl border border-marca-200 bg-white shadow-sm"
  # O espaçamento fica fora da linha, para a linha de dentro (recuada) trocar
  # só ele, sem duas classes de padding brigando
  LINHA = "flex gap-x-4 gap-y-2"
  ESPACO_DA_LINHA = "px-4 py-3 sm:px-5"
  ESPACO_DA_LINHA_RECUADA = "py-2 pl-8 pr-4 sm:pl-10 sm:pr-5"
  TITULO_DA_LINHA = "block text-sm font-semibold text-slate-900"
  SUBTITULO_DA_LINHA = "block text-xs text-slate-600"
  # Segmentos: o rádio fica escondido (sr-only) dentro do rótulo, e o rótulo
  # mostra a opção marcada e o foco
  SEGMENTOS = "inline-flex shrink-0 gap-0.5 self-start rounded-lg border border-marca-300 bg-white p-0.5 sm:self-auto"
  SEGMENTO = "relative cursor-pointer rounded-md px-2.5 py-1.5 text-sm whitespace-nowrap text-slate-700 hover:bg-marca-50 " \
             "has-checked:bg-marca-600 has-checked:font-semibold has-checked:text-white " \
             "has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-marca-700 sm:px-3"
  private_constant :CARTAO, :LINHA, :ESPACO_DA_LINHA, :ESPACO_DA_LINHA_RECUADA, :TITULO_DA_LINHA, :SUBTITULO_DA_LINHA,
                   :SEGMENTOS, :SEGMENTO

  # Um grupo: o título (h2) e a descrição acima do cartão e, no bloco, as
  # linhas. Sem título, só o cartão. id: a âncora do grupo; o título fica em
  # "<id>_titulo", para as linhas citarem (contexto:). acao: um link no canto
  # do título (ex.: "Editar"). lista: true faz do cartão uma <ul>, com cada
  # linha num <li>.
  #   <%= grupo_de_opcoes "Situação", classe: "max-w-2xl" do %>
  #     <%= linha_com_interruptor ... %>
  #   <% end %>
  def grupo_de_opcoes(titulo = nil, id: nil, descricao: nil, acao: nil, lista: false, classe: nil, &linhas)
    cartao = tag.public_send(lista ? :ul : :div, capture(&linhas), class: CARTAO)
    return tag.div(cartao, id:, class: classe) unless titulo

    id_do_titulo = "#{id || "grupo_#{titulo.to_s.parameterize(separator: "_")}"}_titulo"
    cabecalho = tag.div(class: "flex items-end justify-between gap-4") do
      textos = tag.div(class: "min-w-0") do
        safe_join([ tag.h2(titulo, id: id_do_titulo, class: "text-base font-bold text-slate-900"),
                    (tag.p(descricao, class: "text-sm text-slate-600") if descricao) ].compact)
      end
      safe_join([ textos, acao ].compact)
    end
    tag.section(cabecalho + cartao, id:, class: class_names("space-y-2", classe), aria: { labelledby: id_do_titulo })
  end

  # Uma linha com um campo de texto (shared/_campo): rótulo em cima, ajuda e
  # erros embaixo, como no resto do sistema.
  def linha_de_campo(&campo)
    tag.div(capture(&campo), class: "px-4 py-4 sm:px-5")
  end

  # Uma linha que é um link para outra tela (ou modal), com a seta à direita.
  # Os outros atributos vão para o link (ex.: aria: { label: "Editar setor X" }).
  # recuada: true para uma linha que pertence à de cima (ex.: o setor da instituição).
  def linha_de_navegacao(titulo, caminho, subtitulo: nil, recuada: false, **atributos)
    espaco = recuada ? ESPACO_DA_LINHA_RECUADA : ESPACO_DA_LINHA
    classes = "#{LINHA} #{espaco} items-center justify-between hover:bg-marca-50 " \
              "focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-marca-700"
    link_to caminho, class: classes, **atributos do
      texto_da_linha(titulo, subtitulo) + seta
    end
  end

  # Uma linha com interruptor (liga e desliga). A linha inteira é o <label>:
  # clicar em qualquer ponto dela aciona a caixa. O bloco desenha a caixa de
  # marcar (form.check_box ou check_box_tag) com as opções que recebe: elas a
  # transformam no interruptor (role="switch", desenho em opcoes.css) e a ligam
  # ao título e ao subtítulo. contexto: ids de textos que completam o nome lido
  # pelo leitor de tela, quando o título se repete em outros grupos (ex.: o
  # título do grupo da instituição).
  #   <%= linha_com_interruptor "Conta ativa", id: form.field_id(:ativo) do |opcoes| %>
  #     <%= form.check_box :ativo, opcoes %>
  #   <% end %>
  # recuada: true para uma linha que pertence à de cima (ex.: o setor dentro
  # da instituição).
  def linha_com_interruptor(titulo, id:, subtitulo: nil, contexto: nil, recuada: false, &caixa)
    opcoes = { id:, role: "switch", class: "interruptor",
               aria: { labelledby: [ "#{id}_titulo", contexto ].compact.join(" "),
                       describedby: ("#{id}_subtitulo" if subtitulo) }.compact }
    espaco = recuada ? ESPACO_DA_LINHA_RECUADA : ESPACO_DA_LINHA
    tag.label(for: id, class: "#{LINHA} #{espaco} cursor-pointer items-center justify-between hover:bg-marca-50/60") do
      texto_da_linha(titulo, subtitulo, id) + capture(opcoes, &caixa)
    end
  end

  # Uma linha que é uma das opções de uma escolha só, com o rádio à esquerda,
  # como nas listas de escolha do GNOME. A linha inteira é o rótulo. Os rádios
  # de mesmo nome formam o grupo (as setas trocam a opção).
  def linha_com_radio(titulo, id:, nome:, valor:, marcado:, subtitulo: nil)
    radio = radio_button_tag(nome, valor, marcado, id:, class: "mt-0.5 h-4 w-4 shrink-0 cursor-pointer accent-marca-600",
                             aria: { labelledby: "#{id}_titulo", describedby: ("#{id}_subtitulo" if subtitulo) }.compact)
    tag.label(for: id, class: "#{LINHA} #{ESPACO_DA_LINHA} cursor-pointer items-start hover:bg-marca-50/60") do
      radio + texto_da_linha(titulo, subtitulo, id)
    end
  end

  # Uma linha com a escolha entre poucas opções (2 a 4), em segmentos lado a
  # lado: rádios de verdade, escondidos atrás dos rótulos, num grupo com o
  # título da linha (as setas do teclado trocam a opção). Para mais opções, um
  # <select> com ApplicationHelper::CAMPO. recuada: true para uma linha que
  # pertence à de cima (ex.: o formulário dentro do setor).
  #   linha_com_segmentos "Avaliação nutricional", id: "liberacao_3_avaliacao_nutricional", nome: "liberacoes[...]",
  #                       marcado: "consulta", opcoes: [ [ "", "Sem acesso" ], [ "consulta", "Só consulta" ] ]
  def linha_com_segmentos(titulo, id:, nome:, opcoes:, marcado:, subtitulo: nil, contexto: nil, recuada: false)
    segmentos = opcoes.map do |valor, rotulo|
      id_da_opcao = "#{id}_#{valor.presence || "nenhum"}"
      tag.label(for: id_da_opcao, class: SEGMENTO) do
        radio_button_tag(nome, valor, marcado.to_s == valor.to_s, id: id_da_opcao, class: "sr-only") + rotulo
      end
    end
    grupo = tag.div(safe_join(segmentos), role: "radiogroup", class: SEGMENTOS,
                    aria: { labelledby: [ "#{id}_titulo", contexto ].compact.join(" "),
                            describedby: ("#{id}_subtitulo" if subtitulo) }.compact)

    espaco = recuada ? ESPACO_DA_LINHA_RECUADA : ESPACO_DA_LINHA
    tag.div(texto_da_linha(titulo, subtitulo, id) + grupo,
            class: "#{LINHA} #{espaco} flex-col sm:flex-row sm:items-center sm:justify-between")
  end

  private

  # Título e subtítulo de uma linha, em <span> (podem ficar dentro de <label>
  # e de <a>). Com id, cada um ganha o seu, para o controle citar.
  def texto_da_linha(titulo, subtitulo, id = nil)
    tag.span(class: "min-w-0") do
      safe_join([ tag.span(titulo, id: ("#{id}_titulo" if id), class: TITULO_DA_LINHA),
                  (tag.span(subtitulo, id: ("#{id}_subtitulo" if id), class: SUBTITULO_DA_LINHA) if subtitulo) ].compact)
    end
  end

  def seta
    tag.svg(tag.path(d: "m7.5 4.5 5.5 5.5-5.5 5.5"), viewBox: "0 0 20 20", fill: "none", stroke: "currentColor",
            "stroke-width": "2", "stroke-linecap": "round", "stroke-linejoin": "round",
            class: "h-4 w-4 shrink-0 text-marca-500", aria: { hidden: true })
  end
end
