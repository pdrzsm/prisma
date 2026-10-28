# Ícones SVG em linha (traço de 2px, herdam a cor do texto), no desenho do
# Lucide. Ajudam a achar a tela ou a situação de relance; o texto continua ao
# lado, e o ícone fica escondido do leitor de tela.
module IconesHelper
  ICONES = {
    casa: '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M9 22V12h6v10"/>',
    formularios: '<rect width="8" height="4" x="8" y="2"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><path d="M12 11h4M12 16h4M8 11h.01M8 16h.01"/>',
    documento: '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z"/><path d="M14 2v4a2 2 0 0 0 2 2h4M10 9H8M16 13H8M16 17H8"/>',
    predio: '<path d="M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z"/><path d="M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2M10 6h4M10 10h4M10 14h4M10 18h4"/>',
    usuarios: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
    gerador: '<rect width="18" height="7" x="3" y="3"/><rect width="9" height="7" x="3" y="14"/><rect width="5" height="7" x="16" y="14"/>',
    engrenagem: '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>',
    seta_baixo: '<path d="m6 9 6 6 6-6"/>',
    seta_esquerda: '<path d="m15 18-6-6 6-6"/>',
    seta_direita: '<path d="m9 18 6-6-6-6"/>',
    sair: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>',
    grafico: '<path d="M3 3v16a2 2 0 0 0 2 2h16"/><path d="M18 17V9M13 17V5M8 17v-3"/>',
    impressora: '<path d="M6 9V2h12v7"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><path d="M6 14h12v8H6z"/>',
    filtro: '<path d="M22 3H2l8 9.46V19l4 2v-8.46z"/>',
    busca: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    fechar: '<path d="M18 6 6 18M6 6l12 12"/>',
    sino: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
    novidades: '<path d="m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3z"/>',
    lua: '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
    sol: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2m-7.07-2.93 1.41-1.41M17.66 6.34l1.41-1.41M2 12h2M20 12h2M4.93 4.93l1.41 1.41m11.32 11.32 1.41 1.41"/>',
    mais: '<path d="M5 12h14M12 5v14"/>',
    ok: '<path d="M20 6 9 17l-5-5"/>',
    escudo: '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
    pausa: '<circle cx="12" cy="12" r="10"/><path d="M10 15V9M14 15V9"/>',
    chave: '<circle cx="7.5" cy="15.5" r="4.5"/><path d="m10.7 12.3 9.8-9.8M16 7l3 3"/>',
    bloqueio: '<circle cx="12" cy="12" r="10"/><path d="m4.9 4.9 14.2 14.2"/>',
    circulo: '<circle cx="12" cy="12" r="9"/>',
    ponto: '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="1" fill="currentColor"/>',
    lapis: '<path d="M21.2 5.9 18 2.8a1.5 1.5 0 0 0-2.1 0L3 15.7V21h5.3L21.2 8a1.5 1.5 0 0 0 0-2.1z"/><path d="m15 5 4 4"/>',
    alerta: '<path d="m21.7 18-8-14a2 2 0 0 0-3.4 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.7-3"/><path d="M12 9v4M12 17h.01"/>',
    obrigatoria: '<circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/>'
  }.freeze
  private_constant :ICONES

  def icone(nome, classe: "h-4 w-4")
    tag.svg(ICONES.fetch(nome).html_safe, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
            "stroke-width": "2", "stroke-linecap": "round", "stroke-linejoin": "round",
            class: "shrink-0 #{classe}", aria: { hidden: true })
  end

  # O ícone e o texto lado a lado (selos, botões, títulos)
  def com_icone(nome, texto, classe: "gap-1.5")
    tag.span(icone(nome) + texto, class: "inline-flex items-center #{classe}")
  end
end
