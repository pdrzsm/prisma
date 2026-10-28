# O Prisma não usa câmera, microfone, localização nem pagamento: o navegador
# não deve liberar nada disso nem para scripts de terceiros. Cabeçalho escrito
# à mão, na sintaxe atual (camera=()): o DSL do Rails (config.permissions_policy)
# gera a sintaxe antiga do Feature-Policy, que os navegadores ignoram.
Rails.application.config.action_dispatch.default_headers["Permissions-Policy"] =
  "camera=(), microphone=(), geolocation=(), payment=(), usb=()"
