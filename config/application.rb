require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Prisma
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")

    # Horário de Brasília por padrão; outra região: PRISMA_FUSO_HORARIO=America/Manaus
    config.time_zone = ENV.fetch("PRISMA_FUSO_HORARIO", "America/Sao_Paulo")

    # Contato do encarregado de dados (DPO) da instituição, mostrado na página
    # de privacidade (LGPD, art. 41, § 1º). Ex.: "Maria Souza · dpo@hospital.gov.br"
    config.x.encarregado = ENV["PRISMA_ENCARREGADO"].presence

    # Interface em português; o que ainda não tiver tradução cai no inglês
    config.i18n.default_locale = :"pt-BR"
    config.i18n.available_locales = [ :"pt-BR", :en ]
    config.i18n.fallbacks = [ :en ]

    # Configuração de Criptografia do ActiveRecord
    config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
  end
end
