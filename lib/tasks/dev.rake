# Dados fictícios para desenvolvimento. Nunca rodam em produção.
namespace :dev do
  desc "Gera notificações fictícias de seguimento de TB (QUANTIDADE=50; precisa do db:seed)"
  task notificacoes: :environment do
    abort "dev:notificacoes cria dados fictícios e não roda em produção." if Rails.env.production?

    autores = User.where(role: %w[operador admin]).to_a
    abort "Nenhum operador cadastrado. Rode bin/rails db:seed antes." if autores.none? { |autor| autor.role == "operador" }

    quantidade = Integer(ENV.fetch("QUANTIDADE", "50"))
    criadas = NotificacoesFicticias.new(quantidade:, autores:).gerar
    total = AvaliacaoClinica.where(formulario: NotificacoesFicticias::FORMULARIO).count
    puts "#{criadas} notificações fictícias criadas (#{quantidade - criadas} já existiam). Total no formulário: #{total}."
  end
end
