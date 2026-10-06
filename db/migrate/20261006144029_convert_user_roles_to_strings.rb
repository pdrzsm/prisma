class ConvertUserRolesToStrings < ActiveRecord::Migration[8.1]
  # Valor posicional antigo (inteiro gravado em coluna string) => nome explícito
  ROLES = { "0" => "recepcao", "1" => "medico", "2" => "admin" }.freeze

  # Model local: não depende do enum de User, que muda junto com esta migration
  class Usuario < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    # Aborta antes de alterar qualquer coisa se houver papel fora do mapeamento,
    # para nenhum usuário ficar com role nil
    desconhecidos = Usuario.where.not(role: ROLES.keys + ROLES.values).distinct.pluck(:role)
    raise "Papéis desconhecidos em users.role: #{desconhecidos.inspect}" if desconhecidos.any?

    change_column_default :users, :role, from: "0", to: "recepcao"
    ROLES.each { |legado, nome| Usuario.where(role: legado).update_all(role: nome) }
  end

  def down
    change_column_default :users, :role, from: "recepcao", to: "0"
    ROLES.each { |legado, nome| Usuario.where(role: nome).update_all(role: legado) }
  end
end
