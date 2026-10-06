# As chaves vêm de variáveis de ambiente (config/application.rb). Sem elas,
# a aplicação subiria e só falharia na primeira gravação de dado sensível.
# Em produção, melhor não subir. SECRET_KEY_BASE_DUMMY marca o build da
# imagem (assets:precompile), que roda sem segredos.
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  faltando = %w[
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  ].select { |variavel| ENV[variavel].blank? }

  raise "Chaves de criptografia ausentes: #{faltando.join(', ')}. Ver docs/seguranca.md." if faltando.any?
end
