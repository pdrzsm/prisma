# Os privilégios do usuário do banco que a aplicação usa em produção, tabela a
# tabela (docs/seguranca.md, "Checklist de produção"; docs/implantacao.md).
#
# O usuário do app não é o dono do banco. Ele só tem o que o sistema faz:
# - as duas auditorias (audit_logs e versions): só lê e acrescenta, então nem
#   quem invadir o app consegue alterar ou apagar o histórico;
# - o registro clínico e as contas (pacientes, avaliacoes_clinicas, users):
#   lê, acrescenta e altera, mas não apaga ("ninguém apaga um registro clínico
#   nem um usuário": o app nem tem rota para isso);
# - o controle de migrações: só lê (quem migra é outro usuário, em outro
#   container, antes de o app subir);
# - o resto: lê, acrescenta, altera e apaga.
#
# No MariaDB, um GRANT no banco inteiro não pode ser retirado de uma tabela só,
# então os privilégios são dados tabela a tabela. Tabela nova (de uma migração)
# entra com o padrão do "resto"; rode de novo depois de cada migração
# (rails prisma:conceder_privilegios, no .kamal/hooks/pre-app-boot). Quem roda
# precisa poder criar usuários e conceder (o usuário que migra, não o do app).
#
# Refazer os privilégios (tirar tudo e dar de novo) deixa o usuário sem acesso por
# alguns milissegundos, e o app antigo ainda está no ar durante o deploy. Por isso
# só se refaz quando o que o usuário tem difere do esperado: tabela nova, ou um
# privilégio a mais ou a menos (inclusive um dado por fora, como UPDATE em
# audit_logs). Em qualquer dúvida sobre o que o MariaDB devolveu, refaz.
class PrivilegiosDoBanco
  SO_LEITURA_E_INSERCAO = %w[audit_logs versions].freeze
  SEM_EXCLUSAO = %w[pacientes avaliacoes_clinicas users].freeze
  SO_LEITURA = %w[schema_migrations ar_internal_metadata].freeze

  NOME_DO_USUARIO = /\A[a-z][a-z0-9_]{0,31}\z/

  # Uma linha do SHOW GRANTS no nível da tabela: GRANT SELECT, INSERT ON `banco`.`tabela` TO `usuario`@`origem`
  CONCESSAO_NA_TABELA = /\AGRANT (?<privilegios>[A-Z]+(?:, [A-Z]+)*) ON `(?<banco>[^`]+)`\.`(?<tabela>[^`]+)` TO `(?<usuario>[^`]+)`@`(?<origem>[^`]+)`\z/
  SEM_PRIVILEGIO_NENHUM = /\AGRANT USAGE ON \*\.\* /

  # conexao: a do usuário que concede (migra). usuario e senha: os do app.
  # origem: de onde o app conecta ("%" é qualquer lugar; o banco só escuta na
  # rede interna do Docker, sem porta publicada)
  def initialize(conexao, usuario:, senha:, origem: "%")
    raise ArgumentError, "usuário do banco inválido: use letras minúsculas, números e sublinhado" unless usuario.to_s.match?(NOME_DO_USUARIO)
    raise ArgumentError, "informe a senha do usuário do app" if senha.to_s.empty?

    @conexao = conexao
    @usuario = usuario
    @senha = senha
    @origem = origem
  end

  # Quais privilégios cada tabela recebe, na ordem do banco
  def por_tabela
    @conexao.tables.sort.to_h { |tabela| [ tabela, privilegios_de(tabela) ] }
  end

  # Os comandos SQL, na ordem: cria o usuário (ou acerta a senha), tira tudo o
  # que ele tinha e dá o que cabe, tabela a tabela
  def comandos
    comandos_do_usuario + comandos_dos_privilegios
  end

  # Cria o usuário (ou acerta a senha) e, se os privilégios dele não estão como
  # deveriam, refaz todos. Devolve o que cada tabela recebeu.
  def conceder!
    comandos_do_usuario.each { |comando| @conexao.execute(comando) }
    @alterou = !em_dia?
    comandos_dos_privilegios.each { |comando| @conexao.execute(comando) } if @alterou
    por_tabela
  end

  # Os privilégios foram refeitos na última chamada de conceder!?
  def alterou?
    @alterou
  end

  # O usuário tem exatamente os privilégios de por_tabela, nada a mais?
  def em_dia?
    concedidos == por_tabela
  end

  private

  def conta
    "#{@conexao.quote(@usuario)}@#{@conexao.quote(@origem)}"
  end

  def comandos_do_usuario
    [ "CREATE USER IF NOT EXISTS #{conta} IDENTIFIED BY #{@conexao.quote(@senha)}",
      "ALTER USER #{conta} IDENTIFIED BY #{@conexao.quote(@senha)}" ]
  end

  def comandos_dos_privilegios
    banco = @conexao.current_database
    [ "REVOKE ALL PRIVILEGES, GRANT OPTION FROM #{conta}" ] +
      por_tabela.map { |tabela, privilegios| "GRANT #{privilegios.join(', ')} ON #{@conexao.quote_table_name(banco)}.#{@conexao.quote_table_name(tabela)} TO #{conta}" }
  end

  # O que o usuário tem hoje, por tabela. nil se tem qualquer coisa que não seja
  # um privilégio de tabela deste banco, para este usuário e esta origem: no banco
  # inteiro, em coluna, em outro banco, ou com GRANT OPTION.
  def concedidos
    @conexao.select_values("SHOW GRANTS FOR #{conta}").grep_v(SEM_PRIVILEGIO_NENHUM).to_h do |linha|
      concessao = CONCESSAO_NA_TABELA.match(linha)
      return nil unless concessao && concessao[:banco] == @conexao.current_database &&
                        concessao[:usuario] == @usuario && concessao[:origem] == @origem

      [ concessao[:tabela], concessao[:privilegios].split(", ") ]
    end
  end

  def privilegios_de(tabela)
    if SO_LEITURA.include?(tabela) then %w[SELECT]
    elsif SO_LEITURA_E_INSERCAO.include?(tabela) then %w[SELECT INSERT]
    elsif SEM_EXCLUSAO.include?(tabela) then %w[SELECT INSERT UPDATE]
    else %w[SELECT INSERT UPDATE DELETE]
    end
  end
end
