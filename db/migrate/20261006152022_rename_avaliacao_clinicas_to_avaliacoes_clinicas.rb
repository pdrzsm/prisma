# Alinha o nome da tabela com o plural em português definido em
# config/initializers/inflections.rb (rotas e associações já usam esse nome)
class RenameAvaliacaoClinicasToAvaliacoesClinicas < ActiveRecord::Migration[8.1]
  def change
    rename_table :avaliacao_clinicas, :avaliacoes_clinicas
  end
end
