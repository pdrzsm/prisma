# Trilha de auditoria (PaperTrail): quem criou/alterou o quê e quando.
# Atributos criptografados são gravados cifrados também aqui.
class CreateVersions < ActiveRecord::Migration[8.1]
  TEXT_BYTES = 1_073_741_823 # LONGTEXT no MariaDB

  def change
    create_table :versions do |t|
      t.string   :whodunnit
      t.datetime :created_at
      t.bigint   :item_id,   null: false
      t.string   :item_type, null: false
      t.string   :event,     null: false
      t.text     :object, limit: TEXT_BYTES
      t.text     :object_changes, limit: TEXT_BYTES
    end
    add_index :versions, %i[item_type item_id]
  end
end
