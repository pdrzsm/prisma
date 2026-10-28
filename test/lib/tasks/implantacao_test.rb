require "test_helper"
require "rake"

# As tarefas da primeira implantação (lib/tasks/implantacao.rake): a conta admin,
# que o seed se recusa a criar em produção, e os privilégios do usuário do app.
class ImplantacaoTarefasTest < ActiveSupport::TestCase
  SENHA = "cavalo-bateria-grampo-7".freeze

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("prisma:criar_admin")
    # Um terminal de verdade esperaria a digitação: aqui nunca há quem responda
    @stdin = $stdin
    $stdin = StringIO.new
  end

  teardown { $stdin = @stdin }

  test "criar_admin cria a única conta admin, com a troca de senha obrigatória no primeiro acesso" do
    User.admin.update_all(role: "usuario")
    cpf = Cpf.gerar

    com_ambiente("USUARIO" => "nova.admin", "NOME" => "Nova Admin", "CPF" => cpf, "SENHA_TEMPORARIA" => SENHA) do
      assert_difference -> { User.count }, 1 do
        saida, = capture_io { Rake::Task["prisma:criar_admin"].execute }
        assert_match(/Admin @nova\.admin criado/, saida)
        assert_not_includes saida, SENHA
      end
    end

    admin = User.find_by!(username: "nova.admin")
    assert admin.admin?
    assert admin.deve_trocar_senha?
    assert admin.valid_password?(SENHA)
    assert_equal Cpf.normalizar(cpf), admin.cpf
  end

  test "criar_admin recusa quando já existe um admin" do
    com_ambiente("USUARIO" => "outra.admin", "NOME" => "Outra Admin", "CPF" => Cpf.gerar, "SENHA_TEMPORARIA" => SENHA) do
      assert_no_difference -> { User.count } do
        _, erro = capture_io { assert_raises(SystemExit) { Rake::Task["prisma:criar_admin"].execute } }
        assert_includes erro, "Já existe uma conta admin"
      end
    end
  end

  test "criar_admin recusa senha previsível e não cria nada" do
    User.admin.update_all(role: "usuario")

    com_ambiente("USUARIO" => "nova.admin", "NOME" => "Nova Admin", "CPF" => Cpf.gerar, "SENHA_TEMPORARIA" => "12345678") do
      assert_no_difference -> { User.count } do
        _, erro = capture_io { assert_raises(SystemExit) { Rake::Task["prisma:criar_admin"].execute } }
        assert_includes erro, "previsível"
      end
    end
  end

  test "criar_admin sem terminal pede o que falta em vez de ficar esperando" do
    User.admin.update_all(role: "usuario")

    com_ambiente("USUARIO" => nil, "NOME" => "Nova Admin", "CPF" => Cpf.gerar, "SENHA_TEMPORARIA" => SENHA) do
      _, erro = capture_io { assert_raises(SystemExit) { Rake::Task["prisma:criar_admin"].execute } }
      assert_includes erro, "Informe USUARIO"
    end

    com_ambiente("USUARIO" => "nova.admin", "NOME" => "Nova Admin", "CPF" => Cpf.gerar, "SENHA_TEMPORARIA" => nil) do
      _, erro = capture_io { assert_raises(SystemExit) { Rake::Task["prisma:criar_admin"].execute } }
      assert_includes erro, "Informe SENHA_TEMPORARIA"
    end
  end

  test "em produção o db:prepare não roda os seeds, que se recusam a rodar lá" do
    producao = ActiveRecord::Base.configurations.configs_for(env_name: "production", name: "primary")

    assert_not producao.seeds?
  end

  test "conceder_privilegios exige o usuário e a senha do banco que o app usa" do
    com_ambiente("APP_DB_USER" => nil, "APP_DB_PASSWORD" => nil) do
      _, erro = capture_io { assert_raises(SystemExit) { Rake::Task["prisma:conceder_privilegios"].execute } }
      assert_includes erro, "APP_DB_USER"
    end

    com_ambiente("APP_DB_USER" => "prisma_app", "APP_DB_PASSWORD" => nil) do
      _, erro = capture_io { assert_raises(SystemExit) { Rake::Task["prisma:conceder_privilegios"].execute } }
      assert_includes erro, "APP_DB_PASSWORD"
    end
  end

  private

  def com_ambiente(variaveis)
    antigas = variaveis.keys.index_with { |chave| ENV[chave] }
    variaveis.each { |chave, valor| ENV[chave] = valor }
    yield
  ensure
    antigas.each { |chave, valor| ENV[chave] = valor }
  end
end
