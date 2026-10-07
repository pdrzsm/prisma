# O que uma pessoa pode fazer em cada setor e formulário: o RBAC do Prisma.
#
# Uma pessoa usa um formulário num setor só com as TRÊS liberações (nada é
# herdado de um nível para o outro):
#   1. da instituição do setor (LiberacaoInstituicao);
#   2. do setor (LiberacaoSetor);
#   3. do formulário naquele setor, com o papel (LiberacaoFormulario);
# e com o formulário habilitado no setor pelo admin (FormularioHabilitado).
# Tirar qualquer nível corta o acesso aos de baixo.
#
# O admin (conta única) consulta tudo e registra em qualquer setor onde o
# formulário esteja habilitado. Conta desativada não pode nada.
#
# As liberações são lidas do banco uma vez por objeto (User#permissoes guarda
# um por requisição). As policies usam esta classe; nenhuma tela decide acesso
# sozinha.
class Permissoes
  def initialize(user)
    @user = user
  end

  def admin?
    @user.admin? && @user.ativo?
  end

  # "registra", "consulta" ou nil
  def papel(setor_id, formulario)
    return unless setor_id && formulario
    return (habilitados.include?([ setor_id, formulario ]) ? "registra" : "consulta") if admin?

    efetivos[[ setor_id, formulario ]]
  end

  def consulta?(setor_id, formulario) = papel(setor_id, formulario).present?
  def registra?(setor_id, formulario) = papel(setor_id, formulario) == "registra"

  # Ids dos setores em que a pessoa consulta (ou registra) o formulário
  def setores_que_consultam(formulario)
    return Setor.ids if admin?

    efetivos.keys.filter_map { |setor_id, chave| setor_id if chave == formulario }
  end

  def setores_que_registram(formulario)
    return habilitados.filter_map { |setor_id, chave| setor_id if chave == formulario } if admin?

    efetivos.filter_map { |(setor_id, chave), papel| setor_id if chave == formulario && papel == "registra" }
  end

  def consulta_o_formulario?(formulario) = setores_que_consultam(formulario).any?
  def registra_o_formulario?(formulario) = setores_que_registram(formulario).any?

  # Acessos efetivos, para mostrar à pessoa: { [setor_id, formulario] => papel }.
  # Vazio para o admin, que tem acesso a tudo.
  def acessos
    admin? ? {} : efetivos.dup
  end

  # Notificações que a pessoa pode ver: só as dos pares (setor, formulário)
  # liberados. É o escopo de AvaliacaoClinicaPolicy.
  def escopo_de_avaliacoes(scope)
    return scope.all if admin?
    return scope.none if efetivos.empty?

    efetivos.keys.group_by(&:last)
            .map { |formulario, pares| scope.where(formulario:, setor_id: pares.map(&:first)) }
            .reduce(:or)
  end

  private

  # { [setor_id, formulario] => papel }, só com as três liberações e o
  # formulário habilitado no setor
  def efetivos
    @efetivos ||=
      if @user.ativo?
        instituicoes = @user.liberacoes_instituicao.pluck(:instituicao_id).to_set
        setores = @user.liberacoes_setor.joins(:setor).pluck(:setor_id, "setores.instituicao_id")
                       .filter_map { |setor_id, instituicao_id| setor_id if instituicoes.include?(instituicao_id) }
        @user.liberacoes_formulario.where(setor_id: setores, formulario: Formulario.chaves)
             .pluck(:setor_id, :formulario, :papel)
             .select { |setor_id, formulario, _| habilitados.include?([ setor_id, formulario ]) }
             .to_h { |setor_id, formulario, papel| [ [ setor_id, formulario ], papel ] }
      else
        {}
      end
  end

  def habilitados
    @habilitados ||= FormularioHabilitado.where(formulario: Formulario.chaves).pluck(:setor_id, :formulario).to_set
  end
end
