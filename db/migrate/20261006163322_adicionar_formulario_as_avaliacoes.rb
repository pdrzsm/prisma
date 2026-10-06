class AdicionarFormularioAsAvaliacoes < ActiveRecord::Migration[8.1]
  def change
    # Qual definição de config/formularios/ as respostas seguem
    add_column :avaliacoes_clinicas, :formulario, :string, null: false, default: "seguimento_tb"
    change_column_default :avaliacoes_clinicas, :formulario, from: "seguimento_tb", to: nil

    # Bloqueio otimista: duas pessoas editando a mesma notificação não
    # sobrescrevem uma à outra sem aviso
    add_column :avaliacoes_clinicas, :lock_version, :integer, default: 0, null: false

    add_index :avaliacoes_clinicas, %i[formulario updated_at]
  end
end
