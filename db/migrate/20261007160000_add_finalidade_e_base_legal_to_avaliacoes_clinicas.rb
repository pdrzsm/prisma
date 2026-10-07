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
    # legal atuais do formulário. Formulário sem definição em
    # config/formularios para a migração (RecordNotFound): restaure o YAML.
    Avaliacao.reset_column_information
    Avaliacao.distinct.pluck(:formulario).each do |chave|
      definicao = Formulario.find(chave)
      Avaliacao.where(formulario: chave).update_all(finalidade: definicao.finalidade, base_legal: definicao.base_legal)
    end

    change_column_null :avaliacoes_clinicas, :finalidade, false
    change_column_null :avaliacoes_clinicas, :base_legal, false
  end

  def down
    remove_column :avaliacoes_clinicas, :base_legal
    remove_column :avaliacoes_clinicas, :finalidade
  end
end
