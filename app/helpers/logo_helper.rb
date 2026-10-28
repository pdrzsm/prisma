module LogoHelper
  # Facetas do símbolo do Prisma (redesenho de 2026-10-26, logo-prisma.vectorcraft),
  # na ordem de empilhamento do arquivo original (de trás para a frente). É a
  # fonte única do símbolo: o logo cheio (shared/_logo) e o logo em contorno do
  # login (shared/_logo_contorno) são desenhados a partir daqui. Coordenadas do
  # viewBox de RECORTES[:simbolo]. Uma faceta nova aqui precisa de uma linha
  # .contorno-faceta-N em logo_contorno.css.
  #
  # RECORTES[:completo] ainda usa a posição do símbolo antigo (300 0 444 862.4)
  # ao lado do NOME: pendente de redesenho, não usado em nenhuma tela hoje.
  CAMADAS_DO_SIMBOLO = [
    "M116.1,115.81 L180.6,85.78 L243.17,115.81 L216.9,161 L141.74,161 Z",
    "M114.56,229.16 L116.1,115.81 L141.74,161 L141,215.56 Z",
    "M216.9,161 L243.17,115.81 L245.45,229.25 L217.51,215.61 Z",
    "M141,215.56 L141.74,161 L216.9,161 L217.51,215.61 L180.6,197.94 Z",
    "M141,215.56 L180.6,197.94 L217.51,215.61 L217.56,274.22 L141.04,274.22 Z",
    "M114.56,229.16 L141,215.56 L141.04,274.22 Z",
    "M245.45,229.25 L217.51,215.61 L217.56,274.22 Z"
  ].freeze

  # As mesmas facetas, encolhidas ~3 unidades em direção ao próprio centro.
  # Só para o contorno animado (shared/_logo_contorno): como as facetas agora
  # encostam exatamente (sem gap) para o logo cheio ficar sem falha, duas
  # facetas vizinhas tracejam a mesma borda; cada uma anima em ritmo e fase
  # diferentes (logo_contorno.css), e sem esse respiro os dois traços e as
  # duas luzes ficam se contrapondo bem em cima um do outro.
  CAMADAS_DO_SIMBOLO_ENCOLHIDAS = [
    "M119.61,116.48 L180.55,88.1 L239.67,116.48 L214.85,159.17 L143.84,159.17 Z",
    "M115.49,225.86 L116.93,120.18 L140.83,162.31 L140.14,213.18 Z",
    "M217.83,162.31 L242.33,120.16 L244.46,225.96 L218.4,213.24 Z",
    "M143.97,213.61 L144.65,163.25 L214.02,163.25 L214.59,213.66 L180.52,197.35 Z",
    "M143.48,216.85 L180.53,200.36 L215.06,216.89 L215.11,271.72 L143.52,271.72 Z",
    "M116.5,230.31 L140.03,218.21 L140.07,270.42 Z",
    "M243.43,230.38 L218.52,218.22 L218.57,270.47 Z"
  ].freeze

  # O nome, PRIƧM∀, com o S e o A rotacionados: é o desenho do logo, não
  # erro. Um caminho por letra, nas coordenadas do logo inteiro.
  NOME = [
    "M46,446.8c0,2.35-.78,4.29-2.34,5.8s-3.55,2.27-5.97,2.27H10v45H0v-113h37.69c2.42,0,4.41.74,5.97,2.23,1.56,1.49,2.34,3.41,2.34,5.76v51.94ZM36,445.87v-50H10v50h26Z",
    "M112.34,499.87h-10.55l-21.67-60,1.41-2h18.46v-42h-27v104h-11v-113h39.61c2.47,0,4.48.75,6.05,2.24,1.56,1.49,2.34,3.42,2.34,5.78v42.89c0,5.44-3.83,8.16-11.49,8.16-.76,0-1.87-.04-3.33-.11-1.46-.07-2.52-.11-3.18-.11,6.8,18,13.58,36.06,20.33,54.15Z",
    "M139,499.87h-10v-113h10v113Z",
    "M158,465.85c0-3.12,1.05-5.92,3.16-8.41l31.84-37.54v-24.02s-25,0-25,0v25h-10v-26.06c0-2.34.73-4.25,2.19-5.73,1.46-1.48,3.37-2.22,5.72-2.22h29.63c2.47,0,4.49.74,6.07,2.23,1.58,1.49,2.38,3.41,2.38,5.75v22.8c0,3.12-1.13,5.97-3.4,8.56l-32.6,37.54v27.11s25,0,25,0v-28h11v28.92c0,2.38-.83,4.32-2.49,5.83s-3.78,2.26-6.37,2.26h-29.07c-2.4,0-4.34-.74-5.83-2.23-1.49-1.49-2.24-3.4-2.24-5.75v-26.04Z",
    "M280,499.87h-10v-71.41c.53-1.01.88-3.96,1.58-8.85l-19.15,69.25h-2.09l-19.15-69.25c.7,4.94,1.05,7.89.81,8.85v71.41h-10v-113h9.67l19.03,73.5c.1.39.2,1.47.3,3.25,0-.72.1-1.8.3-3.25l19.03-73.5h9.67v113Z",
    "M294.09,386.87h10.65s4.11,25,4.11,25h23.24s4.11-25,4.11-25h9.81v.29s-20.9,112.71-20.9,112.71h-10.26s-20.75-113-20.75-113ZM310.18,420.87l10.25,60.99,10.32-60.99h-20.57Z"
  ].freeze

  # Recorte de cada versão do logo (viewBox), nas coordenadas do arquivo original
  RECORTES = {
    simbolo: "114.55 85.78 130.89 188.45",
    nome: "0 386.87 346.1 113",
    completo: "0 0 744 862.4"
  }.freeze

  # O símbolo (:simbolo) sempre aparece como selo: um quadrado arredondado
  # índigo escuro (fundo escuro, pra cor de cada faceta se destacar), igual ao
  # ícone do navegador (public/icon.svg, docs/identidade-visual.md). Por isso
  # usa cores fixas, não currentColor: o selo é a mesma marca em qualquer
  # fundo. BADGE_RECORTE é o viewBox quadrado, centralizado no símbolo, com a
  # mesma folga do ícone do navegador (margem ~11% do lado); BADGE_RAIO é o
  # raio do canto na mesma proporção (96/512 do ícone).
  BADGE_RECORTE = "59.4 59.4 241.21 241.21"
  BADGE_RAIO = 45.23
  # Cor própria do logo (era o marca-900 da paleta índigo-violeta). Não segue
  # a escala "marca": a paleta do sistema ficou mais sóbria, e a cor forte é
  # justamente o que o logo carrega.
  BADGE_FUNDO = "#312e81"

  # O prisma espectral: cada faceta do símbolo (mesma ordem de
  # CAMADAS_DO_SIMBOLO) numa cor do arco-íris, como a luz branca se abrindo
  # ao atravessar um prisma de verdade. É o único lugar do sistema com cor
  # fora da escala "marca" — o resto fica com uma cor só, pra não virar
  # arco-íris o sistema inteiro (docs/identidade-visual.md, "Logo").
  CORES_DO_ESPECTRO = [
    "#ef4444", # vermelho
    "#f97316", # laranja
    "#f59e0b", # âmbar
    "#22c55e", # verde
    "#0ea5e9", # azul
    "#6366f1", # índigo
    "#a855f7"  # violeta
  ].freeze
end
