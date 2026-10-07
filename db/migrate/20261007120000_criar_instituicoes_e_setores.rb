# Instituições e os seus setores, cadastrados pelo admin em Configurações.
# Os nomes não são dados de paciente: ficam em texto puro, sem cifra.
class CriarInstituicoesESetores < ActiveRecord::Migration[8.1]
  def change
    create_table :instituicoes do |t|
      t.string :nome, null: false, limit: 150
      t.string :sigla, limit: 20
      t.timestamps
    end
    # A collation do banco não diferencia maiúsculas: "Cedap" e "CEDAP" colidem.
    # Sigla em branco fica NULL, e vários NULL não violam o índice único.
    add_index :instituicoes, :nome, unique: true
    add_index :instituicoes, :sigla, unique: true

    create_table :setores do |t|
      # Sem índice próprio: o índice único abaixo começa por instituicao_id
      t.references :instituicao, null: false, index: false, foreign_key: { to_table: :instituicoes }
      t.string :nome, null: false, limit: 150
      t.timestamps
    end
    # O mesmo nome pode existir em instituições diferentes, nunca duas vezes na mesma
    add_index :setores, [ :instituicao_id, :nome ], unique: true
  end
end
