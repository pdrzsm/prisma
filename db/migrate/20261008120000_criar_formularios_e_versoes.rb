# Formulários no banco, montados no gerador (Configurações > Gerador de
# formulários), em versões. O rascunho é editado; a versão publicada nunca
# muda, e cada notificação fica ligada à versão em que foi registrada: mudar o
# formulário depois não invalida nem reinterpreta o que já foi coletado.
class CriarFormulariosEVersoes < ActiveRecord::Migration[8.1]
  def change
    # A chave é o nome do formulário na URL e nas liberações. Só minúsculas,
    # números e "_", começando por letra (o banco confere), e nunca muda
    create_table :formularios do |t|
      t.string :chave, limit: 64, null: false
      t.bigint :versao_publicada_id
      t.timestamps
      t.index :chave, unique: true
      t.index :versao_publicada_id
      t.check_constraint "BINARY chave REGEXP '^[a-z][a-z0-9_]{0,63}$'", name: "formularios_chave"
    end

    # estrutura: a definição inteira, em JSON (DefinicaoDeFormulario). O
    # rascunho tem publicada_em nula, e rascunho_unico garante no banco um
    # rascunho só por formulário (como o admin_unico de users)
    create_table :versoes_formulario do |t|
      t.references :formulario, null: false, index: false, foreign_key: true
      t.integer :numero, null: false
      t.text :estrutura, size: :long, null: false, collation: "utf8mb4_bin"
      t.datetime :publicada_em
      t.references :publicada_por, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      t.virtual :rascunho_unico, type: :bigint, as: "IF(publicada_em IS NULL, formulario_id, NULL)", stored: true
      t.index [ :formulario_id, :numero ], unique: true
      t.index :rascunho_unico, unique: true
      t.check_constraint "json_valid(estrutura)", name: "versoes_formulario_estrutura"
      t.check_constraint "numero > 0", name: "versoes_formulario_numero"
      t.check_constraint "publicada_por_id IS NULL OR publicada_em IS NOT NULL", name: "versoes_formulario_publicacao"
    end
    add_foreign_key :formularios, :versoes_formulario, column: :versao_publicada_id
  end
end
