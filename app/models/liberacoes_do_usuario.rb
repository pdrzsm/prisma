# Grava de uma vez as liberações de uma pessoa, a partir da tela
# Configurações > Usuários > Liberações. Recebe o estado desejado inteiro e
# acerta o banco: cria o que falta, apaga o que saiu e troca papéis, numa
# transação e com cada mudança na auditoria.
#
# Mantém a hierarquia (ver Permissoes): setor só fica se a instituição dele
# estiver marcada; formulário só fica se o setor estiver marcado e o
# formulário habilitado nele. O que vier fora disso (inclusive de um
# formulário adulterado) é ignorado, e desmarcar um nível apaga os de baixo.
class LiberacoesDoUsuario
  def initialize(user)
    @user = user
  end

  # instituicoes: ids marcados; setores: ids marcados;
  # formularios: { setor_id => { chave_do_formulario => "registra" | "consulta" | "" } }
  def atualizar(instituicoes:, setores:, formularios:)
    instituicoes = Instituicao.where(id: Array(instituicoes)).ids.to_set
    setores = Setor.where(id: Array(setores), instituicao_id: instituicoes.to_a).ids.to_set
    desejadas = formularios_desejados(formularios, setores)

    ActiveRecord::Base.transaction do
      sincronizar(@user.liberacoes_instituicao, :instituicao_id, instituicoes)
      sincronizar(@user.liberacoes_setor, :setor_id, setores)
      sincronizar_formularios(desejadas)
    end
  end

  private

  # { [setor_id, chave] => papel }, só nos setores marcados e com o formulário habilitado
  def formularios_desejados(formularios, setores)
    habilitados = FormularioHabilitado.where(setor_id: setores.to_a).pluck(:setor_id, :formulario).to_set
    formularios.to_h.each_with_object({}) do |(setor_id, por_formulario), desejadas|
      setor_id = Integer(setor_id.to_s, exception: false)
      next unless setores.include?(setor_id)

      por_formulario.to_h.each do |chave, papel|
        chave = chave.to_s
        next unless LiberacaoFormulario::PAPEIS.include?(papel) && habilitados.include?([ setor_id, chave ])

        desejadas[[ setor_id, chave ]] = papel
      end
    end
  end

  def sincronizar(associacao, coluna, desejados)
    atuais = associacao.pluck(coluna).to_set
    # destroy_all (e não delete_all): cada exclusão passa pela auditoria
    associacao.where(coluna => (atuais - desejados).to_a).destroy_all
    (desejados - atuais).each { |id| associacao.create!(coluna => id) }
  end

  def sincronizar_formularios(desejadas)
    atuais = @user.liberacoes_formulario.index_by { |liberacao| [ liberacao.setor_id, liberacao.formulario ] }
    atuais.each { |chave, liberacao| liberacao.destroy! unless desejadas.key?(chave) }
    desejadas.each do |(setor_id, formulario), papel|
      liberacao = atuais[[ setor_id, formulario ]] || @user.liberacoes_formulario.build(setor_id:, formulario:)
      liberacao.update!(papel:) if liberacao.new_record? || liberacao.papel != papel
    end
  end
end
