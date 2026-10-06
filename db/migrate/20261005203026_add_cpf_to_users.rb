class AddCpfToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :cpf, :string
    add_index :users, :cpf, unique: true

    # Torna o email opcional no banco, caso o operador não tenha email corporativo
    change_column_null :users, :email, true
  end
end
