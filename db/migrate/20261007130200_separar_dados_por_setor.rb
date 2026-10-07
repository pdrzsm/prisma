# Pacientes e notificações passam a pertencer a um setor: cada setor tem os
# seus pacientes, com prontuário único dentro do setor. O que já existia vai
# para um "Setor inicial" (numa "Instituição inicial"), criado só se houver
# dados, para nada ficar sem setor; o admin pode renomear depois.
class SepararDadosPorSetor < ActiveRecord::Migration[8.1]
  def up
    add_reference :pacientes, :setor, foreign_key: { to_table: :setores }, index: false
    add_reference :avaliacoes_clinicas, :setor, foreign_key: { to_table: :setores }, index: false

    if select_value("SELECT COUNT(*) FROM pacientes").to_i.positive?
      setor_id = setor_inicial
      execute "UPDATE pacientes SET setor_id = #{setor_id}"
      execute "UPDATE avaliacoes_clinicas SET setor_id = #{setor_id}"
      # Os formulários com notificações ficam habilitados no setor
      execute <<~SQL
        INSERT INTO formularios_habilitados (setor_id, formulario, created_at, updated_at)
        SELECT DISTINCT #{setor_id}, formulario, NOW(), NOW() FROM avaliacoes_clinicas
      SQL
    end

    change_column_null :pacientes, :setor_id, false
    change_column_null :avaliacoes_clinicas, :setor_id, false

    # Prontuário único por setor (o mesmo número pode existir em outro setor)
    remove_index :pacientes, :prontuario_sah
    remove_index :pacientes, :prontuario_aghuse
    add_index :pacientes, [ :setor_id, :prontuario_sah ], unique: true
    add_index :pacientes, [ :setor_id, :prontuario_aghuse ], unique: true
    # Lista de um formulário dentro dos setores liberados, da mais recente
    add_index :avaliacoes_clinicas, [ :setor_id, :formulario, :updated_at ]
  end

  def down
    remove_index :avaliacoes_clinicas, [ :setor_id, :formulario, :updated_at ]
    remove_index :pacientes, [ :setor_id, :prontuario_aghuse ]
    remove_index :pacientes, [ :setor_id, :prontuario_sah ]
    add_index :pacientes, :prontuario_sah, unique: true
    add_index :pacientes, :prontuario_aghuse, unique: true
    remove_reference :avaliacoes_clinicas, :setor, foreign_key: { to_table: :setores }
    remove_reference :pacientes, :setor, foreign_key: { to_table: :setores }
  end

  private

  def setor_inicial
    instituicao_id = select_value("SELECT id FROM instituicoes WHERE nome = 'Instituição inicial'") ||
                     insert("INSERT INTO instituicoes (nome, created_at, updated_at) VALUES ('Instituição inicial', NOW(), NOW())")
    select_value("SELECT id FROM setores WHERE instituicao_id = #{instituicao_id.to_i} AND nome = 'Setor inicial'") ||
      insert("INSERT INTO setores (instituicao_id, nome, created_at, updated_at) VALUES (#{instituicao_id.to_i}, 'Setor inicial', NOW(), NOW())")
  end
end
