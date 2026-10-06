class HardenUsers < ActiveRecord::Migration[8.1]
  # Model local: lê CPFs antigos em texto puro para normalizá-los e cifrá-los
  class Usuario < ActiveRecord::Base
    self.table_name = "users"
    encrypts :cpf, deterministic: true, support_unencrypted_data: true
  end

  def change
    # :lockable — bloqueio temporário após senhas erradas seguidas
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_at, :datetime

    # Colunas de módulos do Devise que não são usados (:rememberable, :recoverable)
    remove_column :users, :remember_created_at, :datetime
    remove_index :users, :reset_password_token, unique: true
    remove_column :users, :reset_password_token, :string
    remove_column :users, :reset_password_sent_at, :datetime

    # CPF do operador: só dígitos e criptografado (determinístico, para o login)
    reversible do |direcao|
      Usuario.reset_column_information
      direcao.up { Usuario.find_each { |usuario| usuario.update_columns(cpf: usuario.cpf.to_s.gsub(/[\s.\-\/]/, "")) } }
      direcao.down { Usuario.find_each(&:decrypt) }
    end
    change_column_null :users, :cpf, false
  end
end
