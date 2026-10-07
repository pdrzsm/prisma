require "test_helper"

# Testes que rodam num navegador de verdade (Chrome sem janela): cobrem o que
# só existe no navegador, como o CSS que mostra e esconde perguntas.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Devise::Test::IntegrationHelpers

  # No container de desenvolvimento, Chromium do Debian (CHROME_BIN, ver
  # Dockerfile) rodando como root; no CI, o Chrome do GitHub Actions.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ] do |opcoes|
    opcoes.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    opcoes.add_argument("--no-sandbox") if Process.uid.zero?
    opcoes.add_argument("--disable-dev-shm-usage")
  end
end
