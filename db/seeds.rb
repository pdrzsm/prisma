# Usuários de desenvolvimento, um de cada papel. Pode rodar várias vezes: só
# cria quem ainda não existe e nunca apaga nada. Os CPFs são gerados na hora,
# para nenhum CPF (real ou não) ficar versionado no repositório.
abort "db:seed cria contas com senha conhecida e não roda em produção." if Rails.env.production?

senha = ENV.fetch("SEED_PASSWORD", "prisma-dev-senha")

%w[admin operador consultor].each do |papel|
  User.find_or_create_by!(username: papel) do |user|
    user.role = papel
    user.cpf = Cpf.gerar
    user.password = senha
  end
end

puts "Usuários de desenvolvimento: admin, operador e consultor (senha: #{senha})."
