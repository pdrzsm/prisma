# Liberações de acesso (RBAC). Uma pessoa só usa um formulário num setor com
# as três liberações: da instituição, do setor e do formulário naquele setor
# (com o papel: registra ou só consulta). Nada é herdado de um nível para o
# outro. O formulário também precisa estar habilitado no setor pelo admin.
class CriarLiberacoes < ActiveRecord::Migration[8.1]
  def change
    # Formulários (chaves dos YAML de config/formularios) disponíveis em cada setor
    create_table :formularios_habilitados do |t|
      t.references :setor, null: false, index: false, foreign_key: { to_table: :setores }
      t.string :formulario, null: false, limit: 64
      t.timestamps
    end
    add_index :formularios_habilitados, [ :setor_id, :formulario ], unique: true

    create_table :liberacoes_instituicao do |t|
      t.references :user, null: false, index: false, foreign_key: true
      t.references :instituicao, null: false, foreign_key: { to_table: :instituicoes }
      t.timestamps
    end
    add_index :liberacoes_instituicao, [ :user_id, :instituicao_id ], unique: true

    create_table :liberacoes_setor do |t|
      t.references :user, null: false, index: false, foreign_key: true
      t.references :setor, null: false, foreign_key: { to_table: :setores }
      t.timestamps
    end
    add_index :liberacoes_setor, [ :user_id, :setor_id ], unique: true

    create_table :liberacoes_formulario do |t|
      t.references :user, null: false, index: false, foreign_key: true
      t.references :setor, null: false, foreign_key: { to_table: :setores }
      t.string :formulario, null: false, limit: 64
      t.string :papel, null: false, limit: 16
      t.timestamps
    end
    add_index :liberacoes_formulario, [ :user_id, :setor_id, :formulario ], unique: true, name: "index_liberacoes_formulario_unicas"
    add_check_constraint :liberacoes_formulario, "papel IN ('registra', 'consulta')", name: "liberacoes_formulario_papel"
  end
end
