# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_07_140000) do
  create_table "audit_logs", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "auditable_type", limit: 64, null: false
    t.bigint "auditable_id", null: false
    t.string "action", limit: 20, null: false
    t.string "ip_address", limit: 45
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.index ["auditable_type", "auditable_id", "created_at"], name: "index_audit_logs_on_registro_e_data"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
  end

  create_table "avaliacoes_clinicas", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "paciente_id", null: false
    t.bigint "user_id", null: false
    t.text "dados_formulario", size: :long, collation: "utf8mb4_bin"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "formulario", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "setor_id", null: false
    t.index ["formulario", "updated_at"], name: "index_avaliacoes_clinicas_on_formulario_and_updated_at"
    t.index ["paciente_id"], name: "index_avaliacoes_clinicas_on_paciente_id"
    t.index ["setor_id", "formulario", "updated_at"], name: "idx_on_setor_id_formulario_updated_at_02132e20f9"
    t.index ["user_id"], name: "index_avaliacoes_clinicas_on_user_id"
    t.check_constraint "json_valid(`dados_formulario`)", name: "dados_formulario"
  end

  create_table "formularios_habilitados", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "setor_id", null: false
    t.string "formulario", limit: 64, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["setor_id", "formulario"], name: "index_formularios_habilitados_on_setor_id_and_formulario", unique: true
  end

  create_table "instituicoes", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "nome", limit: 150, null: false
    t.string "sigla", limit: 20
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["nome"], name: "index_instituicoes_on_nome", unique: true
    t.index ["sigla"], name: "index_instituicoes_on_sigla", unique: true
  end

  create_table "liberacoes_formulario", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "setor_id", null: false
    t.string "formulario", limit: 64, null: false
    t.string "papel", limit: 16, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["setor_id"], name: "index_liberacoes_formulario_on_setor_id"
    t.index ["user_id", "setor_id", "formulario"], name: "index_liberacoes_formulario_unicas", unique: true
    t.check_constraint "`papel` in ('registra','consulta')", name: "liberacoes_formulario_papel"
  end

  create_table "liberacoes_instituicao", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "instituicao_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["instituicao_id"], name: "index_liberacoes_instituicao_on_instituicao_id"
    t.index ["user_id", "instituicao_id"], name: "index_liberacoes_instituicao_on_user_id_and_instituicao_id", unique: true
  end

  create_table "liberacoes_setor", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "setor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["setor_id"], name: "index_liberacoes_setor_on_setor_id"
    t.index ["user_id", "setor_id"], name: "index_liberacoes_setor_on_user_id_and_setor_id", unique: true
  end

  create_table "pacientes", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "prontuario_sah"
    t.string "prontuario_aghuse"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "iniciais", limit: 510, null: false
    t.bigint "setor_id", null: false
    t.index ["setor_id", "prontuario_aghuse"], name: "index_pacientes_on_setor_id_and_prontuario_aghuse", unique: true
    t.index ["setor_id", "prontuario_sah"], name: "index_pacientes_on_setor_id_and_prontuario_sah", unique: true
  end

  create_table "setores", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "instituicao_id", null: false
    t.string "nome", limit: 150, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["instituicao_id", "nome"], name: "index_setores_on_instituicao_id_and_nome", unique: true
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "encrypted_password", default: "", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cpf", null: false
    t.string "username", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.string "nome", limit: 150, null: false
    t.boolean "ativo", default: true, null: false
    t.boolean "deve_trocar_senha", default: false, null: false
    t.virtual "admin_unico", type: :integer, as: "if(`role` = 'admin',1,NULL)", stored: true
    t.index ["admin_unico"], name: "index_users_on_admin_unico", unique: true
    t.index ["cpf"], name: "index_users_on_cpf", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "versions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object", size: :long
    t.text "object_changes", size: :long
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "avaliacoes_clinicas", "pacientes"
  add_foreign_key "avaliacoes_clinicas", "setores"
  add_foreign_key "avaliacoes_clinicas", "users"
  add_foreign_key "formularios_habilitados", "setores"
  add_foreign_key "liberacoes_formulario", "setores"
  add_foreign_key "liberacoes_formulario", "users"
  add_foreign_key "liberacoes_instituicao", "instituicoes"
  add_foreign_key "liberacoes_instituicao", "users"
  add_foreign_key "liberacoes_setor", "setores"
  add_foreign_key "liberacoes_setor", "users"
  add_foreign_key "pacientes", "setores"
  add_foreign_key "setores", "instituicoes"
end
