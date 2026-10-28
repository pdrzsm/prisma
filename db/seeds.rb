# Dados de desenvolvimento. Pode rodar várias vezes: só cria o que ainda não
# existe e nunca apaga nada. Os CPFs são gerados na hora, para nenhum CPF
# (real ou não) ficar versionado no repositório.
abort "db:seed cria contas com senha conhecida e não roda em produção." if Rails.env.production?

senha = ENV.fetch("SEED_PASSWORD", "prisma-dev-senha")

# A conta admin é única: só é criada se ainda não existir nenhuma
User.find_or_create_by!(role: "admin") do |novo|
  novo.username = "admin"
  novo.nome = "Administração"
  novo.cpf = Cpf.gerar
  novo.password = senha
end

# Uma instituição e um setor de desenvolvimento. Formulário nenhum: o Prisma
# não traz formulário pronto, nem em desenvolvimento. Monte os seus no gerador
# (Configurações > Gerador de formulários), escolhendo este setor.
instituicao = Instituicao.find_or_create_by!(nome: "Instituição de Desenvolvimento") { |nova| nova.sigla = "DEV" }
setor = instituicao.setores.find_or_create_by!(nome: "Setor de Desenvolvimento")

# Dois usuários comuns, liberados na instituição e no setor. O papel em cada
# formulário (operador registra, consultor só consulta) é dado em Usuários >
# Liberações, depois que o formulário for publicado.
%w[operador consultor].each do |username|
  user = User.find_or_create_by!(username:) do |novo|
    novo.nome = username.capitalize
    novo.role = "usuario"
    novo.cpf = Cpf.gerar
    novo.password = senha
  end
  user.liberacoes_instituicao.find_or_create_by!(instituicao:)
  user.liberacoes_setor.find_or_create_by!(setor:)
end

puts "Desenvolvimento: admin, operador e consultor, senha #{senha}, no #{setor.nome_completo}. " \
     "Nenhum formulário: monte o primeiro no gerador."
