class HardenPacientes < ActiveRecord::Migration[8.1]
  # Model local: lê nomes antigos em texto puro para cifrá-los
  class Paciente < ActiveRecord::Base
    self.table_name = "pacientes"
    encrypts :nome, support_unencrypted_data: true
  end

  def up
    # Texto cifrado ocupa bem mais que o original (base64 + metadados): com 255,
    # um nome de ~130 caracteres já não cabe. 510 é o tamanho do guia do Rails.
    change_column :pacientes, :nome, :string, limit: 510, null: false
    change_column :pacientes, :numero_contatos, :string, limit: 510

    Paciente.reset_column_information
    Paciente.find_each(&:encrypt)

    # Impede paciente duplicado no banco, inclusive em requisições simultâneas
    add_index :pacientes, :cpf, unique: true
  end

  def down
    remove_index :pacientes, :cpf

    Paciente.reset_column_information
    Paciente.find_each(&:decrypt)

    change_column :pacientes, :numero_contatos, :string
    change_column :pacientes, :nome, :string, null: true
  end
end
