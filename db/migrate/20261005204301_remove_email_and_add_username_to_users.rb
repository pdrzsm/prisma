class RemoveEmailAndAddUsernameToUsers < ActiveRecord::Migration[8.0]
  def change
    # Remove a coluna de e-mail e seus índices do MariaDB
    remove_column :users, :email, :string if column_exists?(:users, :email)

    # Garante a coluna username com índice único
    add_column :users, :username, :string, null: false
    add_index :users, :username, unique: true

    # Garante o índice único no CPF (caso ainda não tenha sido criado)
    add_index :users, :cpf, unique: true unless index_exists?(:users, :cpf)
  end
end
