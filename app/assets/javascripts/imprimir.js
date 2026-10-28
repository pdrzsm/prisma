// Botões "Imprimir" (data-imprimir): abrem a impressão do navegador. A CSP só
// aceita script do próprio site, então o clique é ligado aqui, e não na view.
document.addEventListener("click", (evento) => {
  if (evento.target.closest("[data-imprimir]")) window.print()
})
