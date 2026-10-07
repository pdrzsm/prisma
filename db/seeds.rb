# Dados de desenvolvimento. Pode rodar várias vezes: só cria o que ainda não
# existe e nunca apaga nada. Os CPFs são gerados na hora, para nenhum CPF
# (real ou não) ficar versionado no repositório.
abort "db:seed cria contas com senha conhecida e não roda em produção." if Rails.env.production?

senha = ENV.fetch("SEED_PASSWORD", "prisma-dev-senha")

# A conta admin é única: só é criada se ainda não existir nenhuma
User.find_or_create_by!(role: "admin") do |admin|
  admin.username = "admin"
  admin.nome = "Administração"
  admin.cpf = Cpf.gerar
  admin.password = senha
end

# Uma instituição e um setor de desenvolvimento, com o seguimento de TB
instituicao = Instituicao.find_or_create_by!(nome: "Instituição de Desenvolvimento") { |nova| nova.sigla = "DEV" }
setor = instituicao.setores.find_or_create_by!(nome: "Setor de Desenvolvimento")
setor.formularios_habilitados.find_or_create_by!(formulario: "seguimento_tb")

# Dois usuários comuns, liberados nos três níveis: um registra, o outro só consulta
{ "operador" => "registra", "consultor" => "consulta" }.each do |username, papel|
  user = User.find_or_create_by!(username:) do |novo|
    novo.nome = username.capitalize
    novo.role = "usuario"
    novo.cpf = Cpf.gerar
    novo.password = senha
  end
  user.liberacoes_instituicao.find_or_create_by!(instituicao:)
  user.liberacoes_setor.find_or_create_by!(setor:)
  user.liberacoes_formulario.find_or_create_by!(setor:, formulario: "seguimento_tb") { |nova| nova.papel = papel }
end

puts "Desenvolvimento: admin, operador (registra) e consultor (só consulta), senha #{senha}, " \
     "no #{setor.nome_completo}."
