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

ActiveRecord::Schema[8.1].define(version: 2026_10_06_152025) do
  create_table "avaliacoes_clinicas", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "paciente_id", null: false
    t.bigint "user_id", null: false
    t.text "dados_formulario", size: :long, collation: "utf8mb4_bin"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["paciente_id"], name: "index_avaliacoes_clinicas_on_paciente_id"
    t.index ["user_id"], name: "index_avaliacoes_clinicas_on_user_id"
    t.check_constraint "json_valid(`dados_formulario`)", name: "dados_formulario"
  end

  create_table "pacientes", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "nome", limit: 510, null: false
    t.string "cpf"
    t.string "prontuario_sah"
    t.string "prontuario_aghuse"
    t.string "numero_sinan"
    t.boolean "recebe_beneficio_social"
    t.string "municipio_residencia"
    t.string "numero_contatos", limit: 510
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cpf"], name: "index_pacientes_on_cpf", unique: true
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

  add_foreign_key "avaliacoes_clinicas", "pacientes"
  add_foreign_key "avaliacoes_clinicas", "users"
end
