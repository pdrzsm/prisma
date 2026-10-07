require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Prisma: o proxy (kamal-proxy, nginx...) PRECISA terminar o TLS; ver docs/seguranca.md.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :mem_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Prisma: o fallback de idioma (pt-BR -> en) fica em config/application.rb.
  # `true` aqui voltaria para o idioma padrão (pt-BR) e mostraria
  # "translation missing" no que ainda não tem tradução.

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # Prisma: domínios aceitos vêm de APP_HOSTS, separados por vírgula
  # (ex.: "prisma.hospital.gov.br"). Sem a variável, qualquer Host é aceito.
  config.hosts = ENV.fetch("APP_HOSTS", "").split(",").map(&:strip).compact_blank

  # Prisma: IPs do proxy reverso (o que termina o TLS) na frente da aplicação,
  # separados por vírgula; aceita faixas (ex.: "172.20.0.2" ou "10.0.5.0/24").
  # O IP de quem acessa, gravado na auditoria de leitura e usado no limite de
  # tentativas de login, sai do X-Forwarded-For pulando só esses proxies. O
  # padrão do Rails confiaria em toda a rede privada, e qualquer computador da
  # rede interna poderia forjar o próprio IP. Obrigatório: sem ele, a aplicação
  # não sobe (exceto no build dos assets). A aplicação também não pode ser
  # alcançada sem passar pelo proxy (docs/seguranca.md, checklist de produção).
  proxies = ENV.fetch("PROXIES_CONFIAVEIS", "").split(",").map(&:strip).compact_blank
  if proxies.empty? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
    raise "PROXIES_CONFIAVEIS ausente: informe o IP do proxy reverso. Ver docs/seguranca.md."
  end
  config.action_dispatch.trusted_proxies = proxies.map { |proxy| IPAddr.new(proxy) }

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
