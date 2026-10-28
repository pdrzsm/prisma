# As unidades (setores) e as bases (formulários) a que a pessoa tem acesso, de
# Permissoes: a escolha de "Formulários" e de "Relatórios".
module UnidadesComAcesso
  extend ActiveSupport::Concern

  private

  # { setor => [[formulario, papel], ...] }, por nome do setor
  def unidades_com_acesso
    por_setor = Hash.new { |hash, id| hash[id] = [] }
    current_user.permissoes.formularios_consultados.each do |formulario|
      current_user.permissoes.setores_que_consultam(formulario.chave).each do |setor_id|
        por_setor[setor_id] << [ formulario, current_user.permissoes.papel(setor_id, formulario.chave) ]
      end
    end
    Setor.where(id: por_setor.keys).includes(:instituicao).sort_by(&:nome_completo)
         .index_with { |setor| por_setor[setor.id] }
  end
end
