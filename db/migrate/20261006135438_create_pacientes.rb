class CreatePacientes < ActiveRecord::Migration[8.1]
  def change
    create_table :pacientes do |t|
      t.string :nome
      t.string :cpf
      t.string :prontuario_sah
      t.string :prontuario_aghuse
      t.string :numero_sinan
      t.boolean :recebe_beneficio_social
      t.string :municipio_residencia
      t.string :numero_contatos

      t.timestamps
    end
  end
end
