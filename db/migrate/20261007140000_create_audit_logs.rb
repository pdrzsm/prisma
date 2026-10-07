# Auditoria de leitura (LGPD, art. 37 e 46): quem viu quais registros com dado
# sensível de saúde, quando, de qual IP e com qual navegador. O PaperTrail
# (tabela versions) já registra as alterações; esta tabela registra as
# visualizações. Só recebe inserções: não tem updated_at, e o model recusa
# alterar ou apagar (em produção, o usuário do banco também não deve poder;
# ver docs/seguranca.md).
class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      # Usuários nunca são excluídos (só desativados), então a chave estrangeira
      # não impede nada e garante que o autor existe
      t.references :user, null: false, index: false, foreign_key: true
      # O registro visto (polimórfico; hoje, AvaliacaoClinica)
      t.string :auditable_type, null: false, limit: 64
      t.bigint :auditable_id, null: false
      # A action que exibiu o registro: index (lista), show (detalhes) ou edit
      t.string :action, null: false, limit: 20
      t.string :ip_address, limit: 45 # cabe um IPv6
      t.string :user_agent, limit: 255
      t.datetime :created_at, null: false
    end
    # "Quem viu o registro X?" e "o que o usuário Y viu?", em ordem de tempo
    add_index :audit_logs, [ :auditable_type, :auditable_id, :created_at ], name: "index_audit_logs_on_registro_e_data"
    add_index :audit_logs, [ :user_id, :created_at ]
    # Para o descarte por idade (política de retenção)
    add_index :audit_logs, :created_at
  end
end
