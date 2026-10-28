# Cada notificação passa a seguir uma versão do formulário (a publicada quando
# ela foi registrada), e as chaves de formulário das notificações, dos
# formulários habilitados e das liberações passam a apontar, no banco, para um
# formulário que existe (formularios.chave), sempre em minúsculas.
#
# Até aqui, os formulários eram arquivos YAML em config/formularios. Esses
# arquivos não acompanham mais o Prisma (todo formulário é montado no
# gerador): num banco novo, não há nada a converter; num banco antigo, com
# formulários em uso, a migração para e explica o que fazer.
class LigarAvaliacoesAsVersoes < ActiveRecord::Migration[8.1]
  TABELAS = %i[avaliacoes_clinicas formularios_habilitados liberacoes_formulario].freeze

  def up
    add_reference :avaliacoes_clinicas, :versao_formulario, index: true
    converter_formularios_em_uso
    change_column_null :avaliacoes_clinicas, :versao_formulario_id, false
    add_foreign_key :avaliacoes_clinicas, :versoes_formulario, column: :versao_formulario_id

    change_column :avaliacoes_clinicas, :formulario, :string, limit: 64, null: false
    add_index :formularios_habilitados, :formulario
    add_index :liberacoes_formulario, :formulario
    TABELAS.each do |tabela|
      add_check_constraint tabela, "BINARY formulario REGEXP '^[a-z][a-z0-9_]{0,63}$'", name: "#{tabela}_formulario"
      add_foreign_key tabela, :formularios, column: :formulario, primary_key: :chave
    end
  end

  def down
    TABELAS.each do |tabela|
      remove_foreign_key tabela, :formularios, column: :formulario
      remove_check_constraint tabela, name: "#{tabela}_formulario"
    end
    remove_index :liberacoes_formulario, :formulario
    remove_index :formularios_habilitados, :formulario
    change_column :avaliacoes_clinicas, :formulario, :string, null: false
    remove_foreign_key :avaliacoes_clinicas, :versoes_formulario, column: :versao_formulario_id
    remove_reference :avaliacoes_clinicas, :versao_formulario, index: true
  end

  private

  # Os formulários em uso num banco antigo precisariam da definição do arquivo
  # YAML de cada um, que não acompanha mais o Prisma
  def converter_formularios_em_uso
    chaves = TABELAS.flat_map { |tabela| select_values("SELECT DISTINCT formulario FROM #{tabela}") }.uniq
    chaves.each do |chave|
      raise ActiveRecord::MigrationError,
            "O formulário #{chave} tem dados da época em que os formulários eram arquivos YAML (config/formularios), " \
            "que não acompanham mais o Prisma. Migre este banco com uma versão do Prisma que ainda tenha esse arquivo " \
            "(histórico do git) e depois volte a esta."
    end
  end
end
