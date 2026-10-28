# Identidade visual

Cores, fonte, logo e layout das telas do Prisma. O código da paleta e da fonte
está em [app/assets/tailwind/application.css](../app/assets/tailwind/application.css);
as classes reaproveitadas (botões, campos, menu e trilha), em
[ApplicationHelper](../app/helpers/application_helper.rb); os grupos e linhas
das telas de Configurações, em [OpcoesHelper](../app/helpers/opcoes_helper.rb),
e o modal, em [ModalHelper](../app/helpers/modal_helper.rb).

## Cores

O primeiro critério das cores é a **leitura**: um tom calmo e sóbrio, que
funcione igual no modo claro e no noturno. A cor forte fica no logo (as
facetas em cores do espectro, abaixo); o resto do sistema usa uma cor só.

A paleta `marca` é um índigo calmo (2026-10-26). Substituiu um índigo-violeta
saturado (o `indigo` do Tailwind), que durou pouco: os botões e o fundo
lavanda de todas as telas chamavam atenção demais e cansavam a vista, e no
modo noturno ele brigava com a barra lateral azul-marinho. Os hexadecimais
anteriores (índigo-violeta, petróleo e azul-acinzentado) estão no comentário
de [application.css](../app/assets/tailwind/application.css). Use as classes do
Tailwind com esse nome (`bg-marca-600`, `text-marca-700`, `border-marca-200`...).

A escala tem duas metades. Os tons claros (`marca-50` a `marca-300`) são quase
neutros, com um toque de azul: são fundo e borda, e fundo de cor cansa. A cor
aparece do `marca-500` ao `marca-900`: botões, links, foco, selos e o painel do
login. O fundo das telas (`marca-100`) é um cinza-claro neutro, e os cartões
brancos se destacam por cima dele.

O desenho do sistema são os três tons de um prisma, com os cortes em
diagonal: a face escura (`marca-700`), a clara (`marca-100` ou branco) e a do
meio (`marca-300`). Aparece no login e nos avisos. O resto do sistema (barra
lateral, cabeçalho, telas) usa uma superfície só, branca (escura no modo
noturno), com bordas `marca-200`.

| Tom | Cor | Uso |
| --- | --- | --- |
| `marca-50` | `#f8f9fb` | cabeçalho da tabela, opção marcada, hover de botão secundário |
| `marca-100` | `#eceef3` | fundo das telas; filetes entre linhas dos cartões |
| `marca-200` | `#d6d9e6` | bordas de cartões e opções |
| `marca-300` | `#b5bad4` | bordas de campos e botões secundários; terceira face do login |
| `marca-400` | `#848cbd` | borda do aviso; hover de opção marcável e de botão secundário |
| `marca-500` | `#5661ae` | detalhes (números da visão geral, barra de tempo dos avisos), interruptor desligado, borda de campo em foco |
| `marca-600` | `#3f49a2` | botão principal, interruptor ligado, segmento marcado |
| `marca-700` | `#343b89` | links e destaques em texto; hover do botão; painel do login e avisos (face escura); selo "Admin" |
| `marca-800` | `#292d6b` | × do aviso |
| `marca-900` | `#1e204d` | hover de link nas tabelas |

As cores de estado continuam as do Tailwind: `rose` para erro e obrigatória,
`amber` para "Para encerrar", `emerald` para sucesso e "Em acompanhamento".
Com a marca mais sóbria, elas são as únicas cores vivas nas telas, e é isso
que se quer: chamam atenção só onde há algo a ver.

### Contraste

Texto precisa de pelo menos 4,5:1 (WCAG AA); um controle (borda de campo
marcável, interruptor), de 3:1 (WCAG 1.4.11). As combinações em uso:

| Combinação | Contraste |
| --- | --- |
| texto `slate-600` sobre `marca-100` (fundo das telas) | 6,5:1 |
| `slate-500` sobre branco ("Não informado", ajudas) | 4,8:1 |
| `marca-700` sobre branco (links) | 9,9:1 |
| branco sobre `marca-600` (botão principal, segmento marcado) | 7,8:1 |
| branco sobre `marca-700` (painel do login, avisos, selo "Admin") | 9,9:1 |
| branco sobre `marca-500` (números da visão geral) | 5,7:1 |
| `marca-800` sobre `marca-300` (× do aviso) | 6,5:1 |
| `marca-500` sobre branco (interruptor desligado; controle, 3:1) | 5,7:1 |
| `slate-600` sobre branco (item inativo do menu) | 7,6:1 |
| `marca-700` sobre `marca-50` (item ativo do menu) | 9,3:1 |
| `slate-500` sobre branco (rótulo de grupo do menu) | 4,8:1 |

`slate-400` sobre branco dá só 2,6:1: não use para texto (era o "Não
informado" da notificação, que passou para `slate-500`).

### Modo noturno

[tema_escuro.css](../app/assets/stylesheets/tema_escuro.css) troca as
variáveis das cores quando o `<html>` tem `data-tema="escuro"` (cookie `tema`).
As telas não mudam de classe:

- `white` vira a superfície escura (`#171921`: barra lateral, cabeçalho,
  cartões, campos) e o fundo da página fica mais escuro ainda (`#0e0f15`).
  Tinta de baixa saturação, no matiz da marca.
- O selo do logo fica monocromático, nos tons do tema (facetas `slate-800`
  sobre `marca-200`, 9,2:1), em vez das cores do espectro; as facetas variam
  só a opacidade, para o prisma manter o volume.
- Os tons claros da marca (`marca-50` a `marca-300`) e a escala `slate` inteira
  se invertem: o `slate-900` vira o texto mais claro.
- Os tons fortes da marca (`marca-500` a `marca-900`) ficam: são fundo de
  botão, selo e painel, com texto branco por cima. **`text-white` continua
  branco** no modo noturno (só `bg-white` escurece): use-o só sobre fundo de
  cor.
- Texto em `marca-600`/`marca-700` (links, destaques) vira um índigo claro
  (`#a4aeef`); o contorno de foco e os rádios e caixas marcados também.
- Cuidado com o que sempre tem fundo de cor (painel do login, face escura do
  aviso): não use ali um tom claro da marca (`text-marca-100`), que escurece.

| Combinação (modo noturno) | Contraste |
| --- | --- |
| `slate-600` (`#b2b6c7`) sobre a superfície | 8,7:1 |
| `slate-400` (`#888ca0`) sobre a superfície | 5,3:1 |
| links (`#a4aeef`) sobre a superfície | 8,3:1 |
| item ativo do menu (`#a4aeef`) sobre `marca-50` (`#1d1f2a`) | 7,7:1 |
| erro de campo (`rose-600` → `#fb7185`) sobre a superfície | 6,5:1 |
| `marca-500` sobre a superfície (interruptor desligado; controle, 3:1) | 3,1:1 |

## Fonte

[Source Sans 3](https://github.com/adobe-fonts/source-sans), da Adobe, sob a
licença [SIL Open Font License](../app/assets/fonts/OFL-source-sans-3.txt). O
arquivo (`app/assets/fonts/source-sans-3-latin-wght-normal.woff2`) é servido
pelo próprio Prisma e declarado com `@font-face` em
[application.css](../app/assets/stylesheets/application.css): a política de
segurança de conteúdo (CSP) não carrega fontes de outros sites, então não use
Google Fonts nem CDN. É uma fonte variável (pesos 200 a 900) só com caracteres
latinos, o suficiente para o português.

## Logo

O símbolo e o nome vêm do arquivo original do logo e são desenhados por
[shared/_logo.html.erb](../app/views/shared/_logo.html.erb). O nome é escrito
PRIƧM∀: o "S" e o "A" rotacionados **são parte do desenho**, não um erro.
Onde o nome do sistema aparece como marca (login, cabeçalho do celular), use o
desenho do logo, e não o texto "PRISMA" na fonte.

```erb
<%= render "shared/logo", classe: "h-18 w-auto" %>                      <%# só o símbolo %>
<%= render "shared/logo", versao: :nome, classe: "h-14 w-auto" %>       <%# só o nome %>
<%= render "shared/logo", versao: :completo, classe: "h-40 w-auto" %>   <%# símbolo e nome %>
```

O símbolo (`:simbolo`) é sempre um selo: cada faceta numa cor do espectro
(`LogoHelper::CORES_DO_ESPECTRO`) sobre um quadrado arredondado índigo escuro
(`#312e81`, `LogoHelper::BADGE_FUNDO`), com cores fixas (não `currentColor`)
— o prisma abrindo a luz branca em cores, igual ao ícone do navegador
([public/icon.svg](../public/icon.svg) e `icon.png`). É a única parte do
sistema com cor forte fora da escala marca, de propósito: com o resto do
sistema sóbrio, a cor fica no logo. O fundo do selo é cor própria do logo (era
o `marca-900` da paleta índigo-violeta) e não segue a escala marca. É também
uma das duas exceções à regra de cantos retos (a outra é o interruptor, em
"Layout"). No modo noturno, o selo fica
monocromático, nos tons do tema (classe `selo-prisma`, regras em
[tema_escuro.css](../app/assets/stylesheets/tema_escuro.css)); o ícone do
navegador não muda. O nome (`:nome`) continua usando `fill="currentColor"`: a
cor vem da classe de texto do elemento em volta (`text-slate-900` na barra
lateral, `text-white` no login e nos avisos, `text-marca-700` no login do
celular). O contorno animado do login (abaixo) segue a mesma paleta
espectral, faceta por faceta.

As facetas do símbolo ficam em
[LogoHelper](../app/helpers/logo_helper.rb), na ordem de empilhamento (de
trás para a frente). É a fonte única: um logo novo muda ali, e o logo cheio e
o contorno seguem.

### Logo em contorno (login)

[shared/_logo_contorno](../app/views/shared/_logo_contorno.html.erb) desenha só
a linha de cada faceta, no fundo do painel da marca, parada no lugar e a 50% de
opacidade:

1. o traço se desenha, faceta por faceta;
2. uma faixa de luz passa a correr por cada contorno, cada uma no seu ritmo.

É só CSS ([logo_contorno.css](../app/assets/stylesheets/logo_contorno.css)),
sem JavaScript. A CSP não aceita estilo inline, então a ordem e o ritmo de
cada faceta estão nas classes `contorno-faceta-N`: uma faceta nova no
`LogoHelper` precisa de uma linha no CSS. Com "reduzir movimento" ligado no
sistema, o contorno aparece pronto, sem a luz.

## Layout

Cada coisa fica num lugar só: a barra lateral é navegação; o cabeçalho é onde
a pessoa está, a busca e o que é dela (novidades, modo noturno, avisos, conta).

**Cantos retos em todo o sistema**: botões, campos, cartões, menus, janelas,
etiquetas e avisos. O tema do Tailwind zera as classes `rounded-*` com tamanho
(`--radius-*: 0` em
[application.css](../app/assets/tailwind/application.css)), mas `rounded` puro
é um valor fixo e **não** é zerado: não use. Botões têm `border-radius: 0` em
[botoes.css](../app/assets/stylesheets/botoes.css). As únicas exceções, as que
precisam de forma própria: o selo do símbolo (um quadrado de cantos
arredondados, como o ícone do navegador) e o interruptor das telas de
Configurações (uma pílula com bolinha, como no GNOME). As caixas de marcar e os
botões de rádio são os do navegador.

```
┌─────────────────┬───────────────────────────────────────────────────────────┐
│ ▣ PRIƧM∀        │ [<] Formulários / Avaliação   [busca      ] ✦ ☾ 🔔 [@usuário] │
├─────────────────┼───────────────────────────────────────────────────────────┤
│ Visão geral     │                                                           │
│▌Formulários     │  [Filtros]                          [Nova notificação]    │
│ Relatórios      │  ┌─────────────────────────────────────────────────────┐  │
│                 │  │ tabela                                              │  │
│                 │  │                                                     │  │
│                 │  └─────────────────────────────────────────────────────┘  │
│ ─────────────── │                                                           │
│ CONFIGURAÇÕES   │                                                           │
│ Instituições…   │                                                           │
│ Usuários        │                                                           │
│ Gerador…        │                                                           │
└─────────────────┴───────────────────────────────────────────────────────────┘
```

- **Barra lateral** ([shared/_lateral](../app/views/shared/_lateral.html.erb)),
  com 256 px, na mesma superfície do cabeçalho (branca; escura no modo
  noturno) e borda `marca-200` à direita. No alto, o símbolo e o nome, numa
  faixa da altura do cabeçalho e com a mesma borda embaixo, para as duas linhas
  se encontrarem; abaixo, o menu
  ([shared/_menu](../app/views/shared/_menu.html.erb)), que ocupa o resto da
  altura da tela. A largura é a menor em que "Instituições e setores" e
  "Gerador de formulários" cabem numa linha. Numa tela muito baixa, o menu rola
  por dentro e o logo fica parado. No celular (abaixo de 1024 px), a barra
  some e o mesmo menu abre pelo símbolo no cabeçalho, sem JavaScript
  (`<details>`).
- **Menu**: só navegação. Todo item é um link para uma tela, com ícone e texto
  (14 px), cantos retos. No alto, Visão geral, Formulários e Relatórios (somem
  sem nenhum acesso); no **pé da barra**, o grupo "Configurações" (só do
  admin), depois de um filete e com o rótulo em caixa alta (`slate-500`): os
  itens do dia a dia ficam juntos no alto, e a administração, separada. (No
  menu do celular, que não tem altura fixa, o grupo vem logo depois dos
  outros itens.) O item da página atual
  ganha fundo `marca-50`, texto `marca-700` em negrito e um filete
  `marca-600` à esquerda; os outros, hover em `marca-50`. Só um item fica
  ativo por vez (o menu compara `controller_path`, não `controller_name`).
- **Cabeçalho** ([shared/_topo](../app/views/shared/_topo.html.erb)): uma
  fileira só, fixa no alto ao rolar, branca com borda embaixo. À esquerda, o
  botão de voltar (seta, ao nível de cima com caminho; não aparece nas telas de
  primeiro nível) e a trilha; no meio, a busca global (prontuário ou iniciais,
  em qualquer formulário e setor: `/buscar`); à direita, botões de ícone para
  Novidades, modo noturno (um clique) e Avisos, e o nome da pessoa.
  Novidades, Avisos e o nome abrem **menus suspensos** logo abaixo do botão:
  cada um é um `<details>` (sem JavaScript), agrupados por `name`, então abrir
  um fecha o outro, e clicar de novo no botão fecha. O menu do nome mostra quem
  está logado, "Trocar senha" e Sair. "Trocar senha" abre uma **janela no
  centro da tela** (`ModalHelper#janela`, por `?painel=senha`) com os campos e
  um código de confirmação de 6 caracteres que a pessoa redigita
  (`CodigoDeConfirmacao`: fica na sessão, vale 10 minutos e uma vez só). O
  código aparece na própria tela: protege contra troca por engano ou por campos
  preenchidos sozinhos, mas não é segundo fator (o sistema não envia e-mail).
  No celular, a trilha desce para uma segunda linha, o nome vira só o ícone e
  os menus ocupam a largura da tela.
- **Trilha**: numa linha, os níveis separados por "/", o último (a página
  atual) em negrito. Um nível sem caminho no meio (como "Formulários", que é só
  um grupo do menu) fica como texto, sem link. Cada tela declara a sua:

  ```erb
  <% trilha ["Formulários"], [@formulario.titulo] %>
  ```

  A trilha **nunca quebra de linha**: o cabeçalho tem sempre 61 px no desktop,
  a altura da faixa do logo na barra lateral, e as duas linhas se encontram. Os
  níveis somem do começo para o fim conforme a largura que a trilha tem
  (container query do Tailwind, só CSS), e a página atual fica sempre; um
  nível só aparece quando cabe junto com os que vêm depois, pelo tamanho dos
  textos (`ApplicationHelper#trilha`). A seta de voltar continua levando ao
  nível de cima. Os avisos (logo abaixo do cabeçalho) e as âncoras contam com
  essa altura fixa: `html { scroll-padding-top }`
  ([application.css](../app/assets/stylesheets/application.css)) deixa o alvo
  de um link como `#cabecalho` abaixo do cabeçalho, e não atrás dele.

  Quando a trilha já diz onde a pessoa está (lista, visão geral),
  o título da página fica só para leitores de tela
  (`<h1 class="sr-only">`). Nas telas de uma notificação, o título aparece,
  porque traz mais informação (situação, quem registrou).
- **Login**: três tons, como as faces de um prisma. A marca fica num painel
  `marca-700` com borda em diagonal, na mesma inclinação das formas do
  símbolo, e o logo em contorno animado ao fundo; o formulário fica no lado
  claro (`marca-100`), num cartão branco de cantos retos. Uma segunda quebra
  sobe da primeira diagonal até o canto superior direito da tela e abre a
  terceira face (`marca-300`); as três se encontram num ponto da primeira
  diagonal. A quebra passa por trás do formulário, e o cartão o mantém
  legível. No celular, as faces somem e o símbolo com o nome vai para cima do
  formulário.

## Botões

Fundo liso, borda e cantos retos (como o cabeçalho e os campos), iguais em
`<a>`, `<button>` e `<input type="submit">`.

| Constante | Fundo e texto | Borda | Hover | Uso |
| --- | --- | --- | --- | --- |
| `BOTAO_PRIMARIO` | `marca-600`, texto branco | `marca-600` | `marca-700` | a ação principal da tela |
| `BOTAO_SECUNDARIO` | branco, texto `slate-800` | `marca-300` | fundo `marca-50`, borda `marca-400` | cancelar, buscar, ações de apoio |
| `BOTAO_PERIGO` | branco, texto `rose-700` | `rose-300` | fundo `rose-50`, borda `rose-400` | excluir, só na tela de edição |

O desenho está em [botoes.css](../app/assets/stylesheets/botoes.css). Cada
variação troca só as três cores (`--fundo`, `--borda`, `--texto`); o modo
noturno troca as do secundário e do perigo em
[tema_escuro.css](../app/assets/stylesheets/tema_escuro.css).

Nas telas de edição, o Excluir fica na ponta direita da linha do Salvar. Um
formulário não pode ficar dentro de outro, então o botão fica na linha mas
envia um formulário de exclusão separado e escondido, pelo atributo `form`
(`<button form="excluir_setor">`), sem JavaScript.

## Paginação

As listas de notificações terminam num **rodapé de tabela**
([shared/_paginacao](../app/views/shared/_paginacao.html.erb)): dentro da
mesma moldura da tabela, com o fundo `marca-50` do cabeçalho dela e um filete
`marca-200` em cima. Fica fora da rolagem lateral da tabela, para continuar à
vista quando ela é larga. Formulários mostra 14 notificações por página
(`FormulariosController::LIMITE`) e a lista de cada formulário, 15
(`AvaliacoesClinicasController::POR_PAGINA`).

- **À esquerda, a contagem**: "Mostrando 16 a 30 de 50 notificações". Com uma
  página só, "8 notificações", e não há botões.
- **À direita** (só com mais de uma página): Anterior, os números e Próxima.
  São quadrados de 36 px, com o desenho dos botões secundários. A página atual
  é um quadrado cheio em `marca-600` com número branco (7,8:1), sem link e com
  `aria-current="page"`. O Anterior na primeira página e o Próxima na última
  ficam apagados e sem link (`aria-disabled`).
- **Quais números**: a primeira, a última e a atual com uma vizinha de cada
  lado (`1 … 4 5 6 … 20`). Um buraco de uma página só mostra a própria página.
- **No celular**, a contagem fica em cima e, no lugar dos números, "Página 2
  de 4" entre o Anterior e o Próxima.

A primeira página não leva `pagina=` na URL, e os filtros (busca e setor)
acompanham todos os links. A conta (página, intervalo, números) está em
[`Paginacao`](../app/models/paginacao.rb); um valor de `pagina` que não seja
um inteiro positivo vira a primeira, e um depois da última mostra "Não há
registros nesta página". A ordem é por atualização e, em empate, por id, para
uma notificação não aparecer em duas páginas nem em nenhuma.

## Avisos

Os avisos do sistema (o `flash` do Rails: "Notificação registrada.", "Você
não tem permissão…", erros de login) aparecem como pop-ups discretos no alto
da tela, ao centro (no canto direito cobririam o usuário e o botão Sair), em
[shared/_avisos](../app/views/shared/_avisos.html.erb), desenhado uma vez no
layout para todas as telas:

```
┌──────────────┬───────────────────────────────────┬─────┐
│ símbolo NOME ╲ » Notificação registrada.         ╱  ×  │
└──────────────┴───────────────────────────────────┴─────┘
  marca-700      branco                              marca-300
```

- Os três tons e os dois cortes repetem o login: a face escura com o símbolo
  e o nome (PRIƧM∀), a clara com a mensagem e a do meio com o botão de fechar.
- O "»" é verde no aviso de sucesso e vermelho no de erro; a mensagem diz o
  que aconteceu, então a cor não é a única pista.
- O de sucesso some sozinho em 6 s, com uma barra mostrando o tempo, e pausa
  com o mouse ou o foco em cima. O de erro fica até ser fechado.
- Sem JavaScript: cada aviso é um `<dialog open>`, e o × é um
  `form method="dialog"`, que o navegador fecha sozinho. As animações estão em
  [avisos.css](../app/assets/stylesheets/avisos.css); com "reduzir movimento",
  o aviso aparece e some sem deslizar.
- Para avisar algo novo, use o `flash` como sempre (`notice:` para sucesso,
  `alert:` para erro). Erros de uma pergunta do formulário continuam ao lado
  da pergunta, não em aviso.

## Configurações: grupos e linhas

As telas de Configurações seguem as Configurações do GNOME: em vez de campos
soltos, as opções ficam em **grupos**, cada um com um título e, embaixo, um
cartão branco com as **linhas**, separadas por filetes `marca-100`. Cada linha
tem título, subtítulo (opcional) e, à direita, o controle. Tudo vem de
[OpcoesHelper](../app/helpers/opcoes_helper.rb):

```
Centro de Referência Fictício              ← grupo_de_opcoes (título, descrição)
┌─────────────────────────────────────────────┐
│ Acesso à instituição               (──●)    │ ← linha_com_interruptor
│ Desligado, nada desta instituição vale.     │
├─────────────────────────────────────────────┤
│ Setor Ambulatório                  (──●)    │
│     Avaliação nutric. [Sem acesso|Só consulta|▓Registra▓] │ ← linha_com_segmentos (recuada)
├─────────────────────────────────────────────┤
│ Laboratório                            ›    │ ← linha_de_navegacao
└─────────────────────────────────────────────┘
```

| Helper | Quando usar |
| --- | --- |
| `grupo_de_opcoes` | Todo conjunto de opções. Sem título, só o cartão (ex.: os campos de um cadastro). `lista: true` faz do cartão uma `<ul>`. |
| `linha_de_campo` | Um campo de texto (`shared/_campo`), com o rótulo em cima, como no resto do sistema. Campo de texto não vira linha com o rótulo ao lado. |
| `linha_com_interruptor` | Sim ou não (conta ativa, liberar um nível, habilitar um formulário). A linha inteira é o rótulo: clicar nela liga e desliga. |
| `linha_com_segmentos` | Uma escolha entre 2 e 4 opções (o papel numa liberação). Com mais opções, um `<select>` com `CAMPO`. |
| `linha_com_radio` | Uma opção de uma escolha só, com o rádio à esquerda e espaço para o subtítulo (a instituição do formulário). |
| `linha_de_navegacao` | Abre outra tela ou modal (editar um setor, liberações, senha temporária). |

- **Interruptor**: uma caixa de marcar de verdade, com `role="switch"`,
  desenhada em [opcoes.css](../app/assets/stylesheets/opcoes.css) só com fundo,
  como os botões. Desligado: trilha da cor da superfície (branca; escura no
  modo noturno), borda e bolinha `marca-500`. Ligado: trilha `marca-600` e
  bolinha branca, do lado direito. O cinza-claro do GNOME não serve: um
  controle precisa de 3:1 contra o fundo (WCAG 1.4.11), e `marca-500` dá
  5,7:1 sobre o branco e 3,1:1 sobre a superfície do modo noturno. A posição
  da bolinha também mostra o
  estado, não só a cor. Com "reduzir movimento", não desliza; no alto
  contraste do sistema, volta a caixa comum.
- **Segmentos**: rádios de verdade, escondidos atrás dos rótulos, num
  `role="radiogroup"` com o título da linha. As setas trocam a opção; a
  marcada fica em `marca-600` com texto branco (7,8:1).
- **Nome lido pelo leitor de tela**: o controle é ligado ao título da linha
  (`aria-labelledby`) e ao subtítulo (`aria-describedby`). Quando o título se
  repete em outros grupos ("Acesso à instituição", setores de mesmo nome), o
  parâmetro `contexto:` junta o título do grupo ao nome.
- **Botões ficam fora dos cartões**: Salvar, Cancelar e Excluir continuam
  numa linha abaixo dos grupos, com `BOTAO_PRIMARIO`, `BOTAO_SECUNDARIO` e
  `BOTAO_PERIGO`.
- Tabelas que comparam colunas (Usuários, Gerador de formulários) continuam
  tabelas.

## Modais

Cadastrar e editar em Configurações (instituição, setor, usuário, senha
temporária, novo formulário) abrem num **modal por cima da lista**, em vez de levar a uma
página nova. No gerador de formulários, **nova e editar seção, nova e editar
pergunta e remover pergunta** também (por cima do rascunho). Todos são uma
**janela no centro da tela**, com o fundo escurecido. As Liberações, que são
longas, continuam uma página. Os **Filtros** das listas são outra peça: um
painel lateral (`painel_lateral`), no desenho do painel do SGA.

```
┌────────────────────────────────────────────────────┐
│ lista ao fundo, escurecida (inert)                 │
│      ┌──────────────────────────────────────┐      │
│      │ Editar setor                      ×  │      │
│      │ Em Centro de Referência Fictício.    │      │
│      ├──────────────────────────────────────┤      │
│      │ [grupos e linhas]                    │      │
│      │ [Salvar] [Cancelar]        [Excluir] │      │
│      └──────────────────────────────────────┘      │
└────────────────────────────────────────────────────┘
```

Sem JavaScript, o modal é desenhado pelo servidor
([ModalHelper](../app/helpers/modal_helper.rb)). A URL continua a de sempre
(`/configuracoes/instituicoes/1/setores/new`): a tela desenha a lista ao fundo
e o conteúdo num `<dialog open>` na frente. Assim o "voltar" do navegador, os
links diretos e a validação (que redesenha a mesma tela com os erros, com o
modal aberto) funcionam como numa página.

```erb
<%= render "configuracoes/instituicoes/lista" %>
<% modal "Novo setor", descricao: "Em #{@instituicao.nome}.", fechar: configuracoes_instituicoes_path do %>
  <%= render "formulario", setor: @setor %>
<% end %>
```

- O controller carrega a lista também nas telas do modal (`carregar_lista`,
  depois do `authorize` e pelo `policy_scope`, como na lista).
- Com um modal aberto, o layout põe `inert` no resto da página: sem clique,
  sem foco pelo Tab e fora do leitor de tela. O modal fica fora dessa parte, e
  os avisos ficam por cima dele.
- O foco começa no próprio modal (`autofocus`), e o leitor de tela anuncia o
  título (`aria-labelledby`) e a descrição.
- Fechar (×) e Cancelar são links de volta para a lista. Não há fechamento só
  no navegador: ele deixaria a página de fundo inerte. Esc não fecha (precisaria
  de JavaScript).
- A página de fundo não rola ([modal.css](../app/assets/stylesheets/modal.css));
  quem rola é o corpo do modal, quando a janela não cabe na tela (o título e o
  X ficam parados). A janela tem a altura do conteúdo e fica no meio, nos dois
  sentidos; no celular, ocupa a largura da tela com 16 px de margem.
- A largura é `largura:`, uma classe do Tailwind escrita por inteiro na
  chamada (`max-w-xl` por padrão; a pergunta do gerador usa `max-w-2xl`).
- Painel branco (a superfície escura, no modo noturno), com os grupos em
  cartões de borda `marca-200`; o fundo da página fica escurecido por um véu
  preto a 40% (`bg-black/40`). O véu é preto fixo, e não `slate-900`, que o
  modo noturno inverte para quase branco.
- Formulário com ações fixas, com `modal ..., rodape: true`: o bloco traz o
  próprio `<form>` com o corpo que rola (`PAINEL_CORPO`) e o rodapé com as
  ações sempre à vista (`PAINEL_RODAPE`), como no painel lateral. É o caso da
  pergunta e da seção do gerador.

### A pergunta e a seção do gerador

A tela do rascunho (o cabeçalho do formulário, as seções e as perguntas) fica
ao fundo: ela está no parcial
[`rascunhos/_conteudo`](../app/views/configuracoes/rascunhos/_conteudo.html.erb),
que o `show` e os modais das seções e das perguntas desenham do mesmo jeito.
Os links do rascunho levam a âncora do lugar (`#s2`, `#pergunta-peso`), para o
fundo abrir já na seção ou na pergunta, e Fechar e Cancelar voltam a essa
âncora. No modal de editar seção, o Remover (só de seção sem perguntas) fica
na ponta esquerda do rodapé.

O modal é **dinâmico sem JavaScript**: o tipo escolhido na lista "Tipo de
resposta" mostra só os campos dele (limite de caracteres, mínimo e máximo,
data futura, opções), por CSS com `:has()`
([application.css](../app/assets/stylesheets/application.css),
`.pergunta-do-gerador`). O servidor só lê os campos do tipo escolhido
(`PerguntaDoGerador`). Os erros voltam no mesmo modal, com o que foi digitado,
e o aviso do rascunho de trás não repete o erro.

## Convenções

- Faces e cortes do prisma são `clip-path` em classe arbitrária do Tailwind
  (`[clip-path:polygon(0_0,65%_0,100%_100%,0_100%)]`). Os cortes têm só duas
  direções: descendo para a direita, como a primeira diagonal do login, ou
  subindo para a direita, como a segunda quebra. Para três faces, faça os dois
  cortes se encontrarem num ponto.
- Trilha e rótulos curtos (inclusive o rótulo de grupo do menu) ficam em
  caixa alta **pelo CSS** (`uppercase`), não no texto; os itens do menu, não. Leitores de tela leem a palavra normal, e o HTML continua
  igual ao do resto do sistema. Em teste de navegador, o texto vem como
  aparece na tela: compare sem diferenciar maiúsculas
  (`text: /\Aformulários\z/i`).
- Botões e campos usam as constantes `ApplicationHelper::BOTAO_PRIMARIO`,
  `BOTAO_SECUNDARIO`, `BOTAO_PERIGO` e `CAMPO`. Ajuste o tamanho somando
  classes (`"#{ApplicationHelper::CAMPO} h-12"`), sem copiar a lista, e sem
  somar uma classe que brigue com uma da constante (ex.: `py-0` com o
  `py-2.5` dos botões): quem ganha é a ordem do CSS do Tailwind, não a do
  atributo.
- Nada de `style="..."` nem `<style>` na página: a CSP bloqueia. Valores fora
  da escala do Tailwind vão como classe arbitrária
  (`[clip-path:polygon(...)]`) ou em
  [application.css](../app/assets/stylesheets/application.css).
- Elemento `sr-only` dentro de uma área com rolagem (`overflow-x-auto`) precisa
  de um pai `relative`. Sem isso, ele escapa da rolagem e cria rolagem
  horizontal na página inteira no celular.
