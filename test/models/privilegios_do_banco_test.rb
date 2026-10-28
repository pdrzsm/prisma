require "test_helper"

class PrivilegiosDoBancoTest < ActiveSupport::TestCase
  # Só o que a classe usa da conexão: nada é executado no banco. "concedidos" são
  # as linhas que o SHOW GRANTS devolveria.
  Conexao = Struct.new(:tables, :executados, :concedidos) do
    def current_database = "prisma_producao"
    def quote(valor) = "'#{valor}'"
    def quote_table_name(nome) = "`#{nome}`"
    def execute(comando) = (self.executados = executados.to_a << comando)
    def select_values(_sql) = concedidos.to_a
  end

  TABELAS = %w[audit_logs versions pacientes avaliacoes_clinicas users schema_migrations ar_internal_metadata formularios setores].freeze

  def privilegios(tabelas = TABELAS, concedidos: [])
    PrivilegiosDoBanco.new(Conexao.new(tabelas, [], concedidos), usuario: "prisma_app", senha: "segredo")
  end

  # O que o MariaDB devolve para o usuário quando tudo está como deveria
  def grants_em_dia(tabelas = TABELAS)
    [ "GRANT USAGE ON *.* TO `prisma_app`@`%` IDENTIFIED BY PASSWORD '*0123456789ABCDEF'" ] +
      privilegios(tabelas).por_tabela.map { |tabela, lista| "GRANT #{lista.join(', ')} ON `prisma_producao`.`#{tabela}` TO `prisma_app`@`%`" }
  end

  test "as auditorias só leem e acrescentam; o registro clínico e as contas não apagam" do
    por_tabela = privilegios.por_tabela

    assert_equal %w[SELECT INSERT], por_tabela["audit_logs"]
    assert_equal %w[SELECT INSERT], por_tabela["versions"]
    assert_equal %w[SELECT INSERT UPDATE], por_tabela["pacientes"]
    assert_equal %w[SELECT INSERT UPDATE], por_tabela["avaliacoes_clinicas"]
    assert_equal %w[SELECT INSERT UPDATE], por_tabela["users"]
    assert_equal %w[SELECT], por_tabela["schema_migrations"]
    assert_equal %w[SELECT], por_tabela["ar_internal_metadata"]
  end

  test "o resto das tabelas, inclusive as que ainda vão nascer, lê, acrescenta, altera e apaga" do
    por_tabela = privilegios(%w[formularios setores tabela_nova_de_uma_migracao]).por_tabela

    assert_equal [ %w[SELECT INSERT UPDATE DELETE] ], por_tabela.values.uniq
  end

  test "os comandos criam o usuário, tiram tudo e dão tabela a tabela, nunca no banco inteiro" do
    comandos = privilegios.comandos

    assert_equal "CREATE USER IF NOT EXISTS 'prisma_app'@'%' IDENTIFIED BY 'segredo'", comandos[0]
    assert_equal "ALTER USER 'prisma_app'@'%' IDENTIFIED BY 'segredo'", comandos[1]
    assert_equal "REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'prisma_app'@'%'", comandos[2]
    assert_includes comandos, "GRANT SELECT, INSERT ON `prisma_producao`.`audit_logs` TO 'prisma_app'@'%'"
    assert_includes comandos, "GRANT SELECT, INSERT, UPDATE ON `prisma_producao`.`pacientes` TO 'prisma_app'@'%'"
    assert_includes comandos, "GRANT SELECT, INSERT, UPDATE, DELETE ON `prisma_producao`.`formularios` TO 'prisma_app'@'%'"
    # Um GRANT no banco inteiro não se retira de uma tabela só
    assert comandos.drop(3).none? { |comando| comando.include?(".*") || comando.match?(/ALL|GRANT OPTION/) }
    assert_equal 9, comandos.drop(3).size
  end

  test "conceder! sem privilégio nenhum executa os comandos na ordem e devolve o que cada tabela recebeu" do
    conexao = Conexao.new(%w[audit_logs formularios], [], [])
    privilegios = PrivilegiosDoBanco.new(conexao, usuario: "prisma_app", senha: "segredo")
    resultado = privilegios.conceder!

    assert_equal 5, conexao.executados.size
    assert_match(/\ACREATE USER/, conexao.executados.first)
    assert_equal({ "audit_logs" => %w[SELECT INSERT], "formularios" => %w[SELECT INSERT UPDATE DELETE] }, resultado)
    assert privilegios.alterou?
  end

  test "com os privilégios em dia, só acerta a senha e não revoga nada, para o app no ar não ficar sem acesso" do
    conexao = Conexao.new(TABELAS, [], grants_em_dia)
    privilegios = PrivilegiosDoBanco.new(conexao, usuario: "prisma_app", senha: "segredo")

    assert privilegios.em_dia?
    privilegios.conceder!

    assert_equal 2, conexao.executados.size
    assert_match(/\ACREATE USER IF NOT EXISTS/, conexao.executados[0])
    assert_match(/\AALTER USER/, conexao.executados[1])
    assert_not privilegios.alterou?
  end

  test "refaz tudo quando o usuário tem a mais, a menos ou diferente do esperado" do
    em_dia = grants_em_dia
    divergentes = {
      "UPDATE a mais na auditoria" => em_dia.map { |l| l.sub("GRANT SELECT, INSERT ON `prisma_producao`.`audit_logs`", "GRANT SELECT, INSERT, UPDATE ON `prisma_producao`.`audit_logs`") },
      "DELETE a mais no registro clínico" => em_dia.map { |l| l.sub("GRANT SELECT, INSERT, UPDATE ON `prisma_producao`.`pacientes`", "GRANT SELECT, INSERT, UPDATE, DELETE ON `prisma_producao`.`pacientes`") },
      "tabela nova sem concessão" => em_dia.reject { |l| l.include?("`setores`") },
      "tabela que não existe mais" => em_dia + [ "GRANT SELECT ON `prisma_producao`.`tabela_antiga` TO `prisma_app`@`%`" ],
      "banco inteiro" => em_dia + [ "GRANT ALL PRIVILEGES ON `prisma_producao`.* TO `prisma_app`@`%`" ],
      "privilégio global" => em_dia + [ "GRANT SELECT ON *.* TO `prisma_app`@`%`" ],
      "com GRANT OPTION" => em_dia.map { |l| l.end_with?("`audit_logs` TO `prisma_app`@`%`") ? "#{l} WITH GRANT OPTION" : l },
      "em outro banco" => em_dia.map { |l| l.sub("`prisma_producao`.`users`", "`outro`.`users`") },
      "só em coluna" => em_dia.map { |l| l.sub("GRANT SELECT, INSERT, UPDATE ON `prisma_producao`.`users`", "GRANT SELECT (id) ON `prisma_producao`.`users`") }
    }

    divergentes.each do |situacao, linhas|
      conexao = Conexao.new(TABELAS, [], linhas)
      privilegios = PrivilegiosDoBanco.new(conexao, usuario: "prisma_app", senha: "segredo")
      privilegios.conceder!

      assert privilegios.alterou?, situacao
      assert_includes conexao.executados, "REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'prisma_app'@'%'", situacao
      assert_equal 2 + 1 + TABELAS.size, conexao.executados.size, situacao
    end
  end

  test "recusa usuário com nome estranho e senha em branco" do
    [ "", "Prisma", "prisma app", "app'; DROP", "1app", "a" * 40 ].each do |nome|
      assert_raises(ArgumentError, nome) { PrivilegiosDoBanco.new(Conexao.new([], [], []), usuario: nome, senha: "x") }
    end
    assert_raises(ArgumentError) { PrivilegiosDoBanco.new(Conexao.new([], [], []), usuario: "prisma_app", senha: "") }
  end

  test "as tabelas restritas existem no banco: um nome trocado deixaria a restrição sumir sem aviso" do
    existentes = ActiveRecord::Base.connection.tables
    restritas = PrivilegiosDoBanco::SO_LEITURA_E_INSERCAO + PrivilegiosDoBanco::SEM_EXCLUSAO + PrivilegiosDoBanco::SO_LEITURA

    assert_empty restritas - existentes
  end
end
