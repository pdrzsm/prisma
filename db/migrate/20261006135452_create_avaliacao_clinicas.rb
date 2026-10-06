class CreateAvaliacaoClinicas < ActiveRecord::Migration[8.1]
  def change
    create_table :avaliacao_clinicas do |t|
      t.references :paciente, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.json :dados_formulario

      t.timestamps
    end
  end
end
