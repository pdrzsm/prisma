namespace :prisma do
  desc "Dá ao usuário do banco do app (APP_DB_USER, APP_DB_PASSWORD) só o que ele precisa, tabela a tabela. Roda com o usuário que migra (DATABASE_URL), depois das migrações."
  task conceder_privilegios: :environment do
    usuario = ENV.fetch("APP_DB_USER") { abort "Informe APP_DB_USER: o usuário do banco que o app usa." }
    senha = ENV.fetch("APP_DB_PASSWORD") { abort "Informe APP_DB_PASSWORD: a senha desse usuário." }

    privilegios = PrivilegiosDoBanco.new(ActiveRecord::Base.connection, usuario:, senha:, origem: ENV.fetch("APP_DB_ORIGIN", "%"))
    por_tabela = privilegios.conceder!
    restritas = por_tabela.reject { |_, lista| lista.size == 4 }
    puts "#{usuario}: privilégios #{privilegios.alterou? ? 'refeitos' : 'já estavam em dia'} em #{por_tabela.size} tabelas. Com restrição:"
    restritas.each { |tabela, lista| puts "  #{tabela}: #{lista.join(', ')}" }
  end

  desc "Cria a conta admin (a única do sistema), com uma senha temporária que a pessoa troca no primeiro acesso. No terminal, pergunta o login, o nome, o CPF e a senha (que não aparece); sem terminal, informe USUARIO, NOME, CPF e SENHA_TEMPORARIA."
  task criar_admin: :environment do
    abort "Já existe uma conta admin: @#{User.admin.first.username}." if User.admin.exists?

    com_terminal = $stdin.tty?
    perguntar = lambda do |variavel, rotulo|
      ENV[variavel].presence || begin
        abort "Informe #{variavel}: sem terminal para perguntar." unless com_terminal
        print "#{rotulo}: "
        $stdin.gets.to_s.strip
      end
    end
    # A senha não ecoa no terminal e é pedida duas vezes, para um erro de digitação
    # não deixar a conta com uma senha que ninguém sabe
    pedir_senha = lambda do |rotulo|
      require "io/console"
      print "#{rotulo} (não aparece): "
      $stdin.noecho(&:gets).to_s.chomp.tap { puts }
    end

    usuario = perguntar.call("USUARIO", "Login (em minúsculas)")
    nome = perguntar.call("NOME", "Nome completo")
    cpf = perguntar.call("CPF", "CPF")
    senha = ENV["SENHA_TEMPORARIA"].presence || begin
      abort "Informe SENHA_TEMPORARIA: sem terminal para perguntar." unless com_terminal
      pedir_senha.call("Senha temporária").tap do |digitada|
        abort "As senhas não são iguais. Nada foi criado." unless digitada == pedir_senha.call("Repita a senha")
      end
    end

    admin = User.new(username: usuario, nome:, cpf:, role: "admin", password: senha, deve_trocar_senha: true)
    abort "Não criou: #{admin.errors.full_messages.to_sentence}." unless admin.save
    puts "Admin @#{admin.username} criado. No primeiro acesso, a senha precisa ser trocada."
  end
end
