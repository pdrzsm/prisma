class ConsolidateUserRolesIntoOperador < ActiveRecord::Migration[8.1]
  # Recepção e médico viram um único papel de operador; consultor passa a existir
  LEGADOS = %w[recepcao medico].freeze
  VALIDOS = %w[operador consultor admin].freeze

  # Model local: não depende do enum de User, que muda junto com esta migration
  class Usuario < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    # Aborta antes de alterar qualquer coisa se houver papel fora do mapeamento
    desconhecidos = Usuario.where.not(role: LEGADOS + VALIDOS).distinct.pluck(:role)
    raise "Papéis desconhecidos em users.role: #{desconhecidos.inspect}" if desconhecidos.any?

    # Sem default: nenhum papel é "menor privilégio" (consultor lê dados de saúde,
    # operador grava), então todo usuário precisa receber um papel explícito
    change_column_default :users, :role, from: "recepcao", to: nil
    Usuario.where(role: LEGADOS).update_all(role: "operador")
  end

  def down
    # Não há como saber quem era recepção e quem era médico
    raise ActiveRecord::IrreversibleMigration
  end
end
