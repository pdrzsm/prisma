# Usuários no modelo de liberações: o papel global passa a ser só "admin" ou
# "usuario" (o que cada usuário faz vem das liberações por setor e
# formulário), com nome, conta ativa e troca de senha obrigatória.
class PrepararUsuariosParaLiberacoes < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :nome, :string, limit: 150
    add_column :users, :ativo, :boolean, default: true, null: false
    add_column :users, :deve_trocar_senha, :boolean, default: false, null: false

    execute "UPDATE users SET nome = username"
    change_column_null :users, :nome, false
    # operador e consultor viram usuários; o que cada um faz passa a ser liberado por setor
    execute "UPDATE users SET role = 'usuario' WHERE role IN ('operador', 'consultor')"

    admins = select_value("SELECT COUNT(*) FROM users WHERE role = 'admin'").to_i
    raise "Há #{admins} contas admin; deixe só uma antes de migrar." if admins > 1

    # Admin único garantido pelo banco: a coluna vale 1 só para o admin (NULL
    # para os outros, e vários NULL não violam o índice único)
    add_column :users, :admin_unico, :virtual, type: :integer, as: "IF(role = 'admin', 1, NULL)", stored: true
    add_index :users, :admin_unico, unique: true
  end

  def down
    remove_index :users, :admin_unico
    remove_column :users, :admin_unico
    execute "UPDATE users SET role = 'operador' WHERE role = 'usuario'"
    remove_column :users, :deve_trocar_senha
    remove_column :users, :ativo
    remove_column :users, :nome
  end
end
