# Cada formulário passa a pertencer a uma instituição e só é habilitado em
# setores dela. Os formulários que já existem ficam com a instituição em que
# têm mais notificações (no empate, a com mais setores; depois, a de menor
# id); um formulário que não está em nenhum setor fica com a primeira
# instituição, e a tela deixa trocar enquanto ele não entrar num setor.
#
# Nada é apagado nem movido: um setor de outra instituição que já tinha o
# formulário continua com ele, porque as notificações dele estão lá (registro
# clínico é preservado). A tela mostra esse setor como anterior à regra.
class LigarFormulariosAInstituicoes < ActiveRecord::Migration[8.1]
  def up
    add_reference :formularios, :instituicao, foreign_key: true, null: true, after: :chave

    formularios = select_rows("SELECT id, chave FROM formularios")
    if formularios.any?
      primeira = select_value("SELECT MIN(id) FROM instituicoes")
      raise "Há formulários e nenhuma instituição: cadastre uma instituição e rode a migração de novo." unless primeira

      formularios.each do |id, chave|
        chave = connection.quote(chave)
        escolhida = select_value(<<~SQL.squish) || primeira
          SELECT setores.instituicao_id
          FROM formularios_habilitados
          JOIN setores ON setores.id = formularios_habilitados.setor_id
          LEFT JOIN avaliacoes_clinicas ON avaliacoes_clinicas.setor_id = setores.id AND avaliacoes_clinicas.formulario = #{chave}
          WHERE formularios_habilitados.formulario = #{chave}
          GROUP BY setores.instituicao_id
          ORDER BY COUNT(avaliacoes_clinicas.id) DESC, COUNT(DISTINCT setores.id) DESC, setores.instituicao_id
          LIMIT 1
        SQL
        update("UPDATE formularios SET instituicao_id = #{connection.quote(escolhida)} WHERE id = #{connection.quote(id)}")
      end
    end

    change_column_null :formularios, :instituicao_id, false
  end

  def down
    remove_reference :formularios, :instituicao, foreign_key: true
  end
end
