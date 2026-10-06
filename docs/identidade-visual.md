# Identidade visual

Cores, fonte, logo e layout das telas do Prisma. O código da paleta e da fonte
está em [app/assets/tailwind/application.css](../app/assets/tailwind/application.css);
as classes reaproveitadas (botões, campos, menu e trilha), em
[ApplicationHelper](../app/helpers/application_helper.rb).

## Cores

A paleta `marca` parte das duas cores do layout: `marca-500`, a barra lateral,
e `marca-100`, o fundo das telas. Use as classes do Tailwind com esse nome
(`bg-marca-500`, `text-marca-700`, `border-marca-200`...).

| Tom | Cor | Uso |
| --- | --- | --- |
| `marca-50` | `#f4f6fb` | cabeçalho da tabela, opção marcada, hover de botão secundário |
| `marca-100` | `#e9edf7` | fundo das telas; logo sobre a barra lateral |
| `marca-200` | `#d3daeb` | bordas de cartões e opções |
| `marca-300` | `#b3bdd6` | bordas de campos e botões secundários; terceira face do login |
| `marca-500` | `#6d7da2` | barra lateral |
| `marca-600` | `#586788` | botão principal; item ativo do menu |
| `marca-700` | `#47536f` | links e destaques em texto; painel da marca do login |

As cores de estado continuam as do Tailwind: `rose` para erro e obrigatória,
`amber` para "Para encerrar", `emerald` para sucesso e "Em acompanhamento".

### Contraste

Texto precisa de pelo menos 4,5:1 (WCAG AA). As combinações em uso:

| Combinação | Contraste |
| --- | --- |
| texto `slate-600` sobre `marca-100` | 6,5:1 |
| `marca-700` sobre branco | 7,7:1 |
| branco sobre `marca-600` (botão principal) | 5,7:1 |
| branco sobre `marca-500` (menu lateral) | **4,1:1** |

O texto do menu lateral fica abaixo de 4,5:1. Escurecer a barra para `#677699`
(6% mais escura) chegaria a 4,5:1 com texto branco; a cor atual foi mantida por
ser a do layout. O logo sobre `marca-500` (3,5:1) está ok: gráficos precisam
de 3:1.

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

O SVG usa `fill="currentColor"`: a cor vem da classe de texto do elemento em
volta (`text-marca-100` na barra lateral, `text-marca-500` no login do
celular). Os ícones do navegador
([public/icon.svg](../public/icon.svg) e `icon.png`) são o símbolo em
`marca-100` sobre um quadrado `marca-500`.

As facetas do símbolo ficam em
[LogoHelper](../app/helpers/logo_helper.rb), em três camadas (de trás para a
frente). É a fonte única: um logo novo muda ali, e o logo cheio e o contorno
seguem.

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

```
┌──────────┬──────────────────────────────────────────────────────────┐
│  símbolo │  CENTRAL DE FORMULÁRIOS CLÍNICOS       [@usuário] [SAIR] │
│          │  FORMULÁRIOS                                             │
│ VISÃO    │      SEGUIMENTO DE TB          ← trilha                  │
│ GERAL    │                                                          │
│          │  [busca        ] [Buscar]           [Nova notificação]   │
│ › FORMU- │  ┌────────────────────────────────────────────────────┐  │
│   LÁRIOS │  │ tabela                                             │  │
│   SEGUI- │  └────────────────────────────────────────────────────┘  │
│   MENTO  │                                                          │
└──────────┴──────────────────────────────────────────────────────────┘
```

- **Barra lateral** ([shared/_lateral](../app/views/shared/_lateral.html.erb)),
  com 152 px, em `marca-500`: símbolo e menu
  ([shared/_menu](../app/views/shared/_menu.html.erb)). Cada formulário de
  `config/formularios/` entra sozinho no menu, abaixo de "Formulários". No
  celular (abaixo de 1024 px), a barra some e o mesmo menu abre pelo símbolo no
  topo, sem JavaScript (`<details>`).
- **Topo** ([shared/_topo](../app/views/shared/_topo.html.erb)): nome do
  sistema, trilha, usuário com o papel e o botão Sair.
- **Trilha**: um nível por linha, cada um recuado sob o anterior, e o último é a
  página atual. Cada tela declara a sua:

  ```erb
  <% trilha ["Formulários", formularios_path], [@formulario.titulo] %>
  ```

  Quando a trilha já diz onde a pessoa está (lista, formulários, visão geral),
  o título da página fica só para leitores de tela
  (`<h1 class="sr-only">`). Nas telas de uma notificação, o título aparece,
  porque traz mais informação (situação, quem registrou).
- **Login**: três tons, como as faces de um prisma. A marca fica num painel
  `marca-700` com borda em diagonal, na mesma inclinação das formas do
  símbolo, e o logo em contorno animado ao fundo; o formulário fica sozinho
  no lado claro (`marca-100`), num cartão branco. Uma segunda quebra sobe da
  primeira diagonal até o canto superior direito da tela e abre a terceira
  face (`marca-300`); as três se encontram num ponto da primeira diagonal. A
  quebra passa por trás do formulário, e o cartão o mantém legível. No celular, o painel some e o
  símbolo com o nome vai para cima do formulário.

## Convenções

- Menu, trilha e rótulos curtos ficam em caixa alta **pelo CSS** (`uppercase`),
  não no texto. Leitores de tela leem a palavra normal, e o HTML continua
  igual ao do resto do sistema. Em teste de navegador, o texto vem como
  aparece na tela: compare sem diferenciar maiúsculas
  (`text: /\Aformulários\z/i`).
- Botões e campos usam as constantes `ApplicationHelper::BOTAO_PRIMARIO`,
  `BOTAO_SECUNDARIO` e `CAMPO`. Ajuste o tamanho somando classes
  (`"#{ApplicationHelper::CAMPO} h-12"`), sem copiar a lista.
- Nada de `style="..."` nem `<style>` na página: a CSP bloqueia. Valores fora
  da escala do Tailwind vão como classe arbitrária
  (`[clip-path:polygon(...)]`) ou em
  [application.css](../app/assets/stylesheets/application.css).
- Elemento `sr-only` dentro de uma área com rolagem (`overflow-x-auto`) precisa
  de um pai `relative`. Sem isso, ele escapa da rolagem e cria rolagem
  horizontal na página inteira no celular.
