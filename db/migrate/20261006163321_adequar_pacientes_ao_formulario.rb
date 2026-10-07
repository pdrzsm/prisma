# O formulário de seguimento identifica o paciente só por prontuários e
# iniciais (sem nome completo nem CPF). Número SINAN, município, benefício e
# número de contatos passam para as respostas do formulário, que são cifradas.
class AdequarPacientesAoFormulario < ActiveRecord::Migration[8.1]
  def change
    reversible do |direcao|
      direcao.up do
        raise "Há pacientes cadastrados; esta migration supõe a tabela vazia." if select_value("SELECT 1 FROM pacientes LIMIT 1")
      end
    end

    remove_index :pacientes, :cpf, unique: true
    remove_column :pacientes, :cpf, :string
    remove_column :pacientes, :nome, :string, limit: 510, null: false
    remove_column :pacientes, :numero_sinan, :string
    remove_column :pacientes, :recebe_beneficio_social, :boolean
    remove_column :pacientes, :municipio_residencia, :string
    remove_column :pacientes, :numero_contatos, :string, limit: 510

    add_column :pacientes, :iniciais, :string, limit: 510, null: false
    # Um prontuário pertence a um só paciente
    add_index :pacientes, :prontuario_sah, unique: true
    add_index :pacientes, :prontuario_aghuse, unique: true
  end
end
