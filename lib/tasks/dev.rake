# Dados fictícios para desenvolvimento. Nunca rodam em produção.
namespace :dev do
  desc "Gera notificações fictícias de seguimento de TB num setor (QUANTIDADE=50, SETOR=id; precisa do db:seed)"
  task notificacoes: :environment do
    abort "dev:notificacoes cria dados fictícios e não roda em produção." if Rails.env.production?

    formulario = NotificacoesFicticias::FORMULARIO
    setores = Setor.joins(:formularios_habilitados).where(formularios_habilitados: { formulario: })
    setor = ENV["SETOR"] ? setores.find_by(id: ENV["SETOR"]) : setores.order(:id).first
    abort "Nenhum setor com o #{formulario} habilitado#{" com o id #{ENV["SETOR"]}" if ENV["SETOR"]}. Rode bin/rails db:seed antes." unless setor

    # Autores: quem registra o formulário no setor (o admin registra em todos)
    autores = User.where(ativo: true).select { |user| user.permissoes.registra?(setor.id, formulario) }
    quantidade = Integer(ENV.fetch("QUANTIDADE", "50"))
    criadas = NotificacoesFicticias.new(quantidade:, autores:, setor:).gerar
    total = AvaliacaoClinica.where(formulario:, setor:).count
    puts "#{criadas} notificações fictícias criadas em #{setor.nome_completo} (#{quantidade - criadas} já existiam). " \
         "Total no setor: #{total}."
  end
end
