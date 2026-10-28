# Finalidade e base legal da coleta gravadas em cada notificação (LGPD, art.
# 6º, X: prestação de contas). Vêm do formulário no registro e não mudam
# depois: se a definição do formulário mudar, a notificação continua dizendo
# para que e com qual base legal foi coletada.
class AddFinalidadeEBaseLegalToAvaliacoesClinicas < ActiveRecord::Migration[8.1]
  # Só a tabela, sem as regras do model de hoje
  class Avaliacao < ActiveRecord::Base
    self.table_name = "avaliacoes_clinicas"
  end

  def up
    add_column :avaliacoes_clinicas, :finalidade, :text
    add_column :avaliacoes_clinicas, :base_legal, :text

    # As notificações que já existem foram coletadas com a finalidade e a base
    # legal do formulário, que então era um arquivo YAML em config/formularios.
    # Esses arquivos não acompanham mais o Prisma (todo formulário é montado no
    # gerador): num banco novo não há nada aqui; num banco antigo, com
    # notificações, a migração para e explica o que fazer.
    Avaliacao.reset_column_information
    Avaliacao.distinct.pluck(:formulario).each do |chave|
      raise ActiveRecord::MigrationError,
            "O formulário #{chave} tem dados da época em que os formulários eram arquivos YAML (config/formularios), " \
            "que não acompanham mais o Prisma. Migre este banco com uma versão do Prisma que ainda tenha esse arquivo " \
            "(histórico do git) e depois volte a esta."
    end

    change_column_null :avaliacoes_clinicas, :finalidade, false
    change_column_null :avaliacoes_clinicas, :base_legal, false
  end

  def down
    remove_column :avaliacoes_clinicas, :base_legal
    remove_column :avaliacoes_clinicas, :finalidade
  end
end
