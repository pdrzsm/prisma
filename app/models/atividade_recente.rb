# O que outras pessoas fizeram nas notificações que esta pessoa pode ver: as
# últimas alterações da auditoria (PaperTrail), para o painel "Avisos" do topo.
# Só diz qual formulário, em qual setor, quem e quando: nenhum dado de paciente
# (abrir a notificação é que entra na auditoria de leitura).
class AtividadeRecente
  Item = Data.define(:quando, :acao, :autor, :avaliacao)

  LIMITE = 15

  # visiveis: o escopo de AvaliacaoClinica da pessoa (AvaliacaoClinicaPolicy::Scope)
  def initialize(user, visiveis)
    @user = user
    @visiveis = visiveis
  end

  def itens
    @itens ||= begin
      versoes = PaperTrail::Version.where(item_type: "AvaliacaoClinica", item_id: @visiveis.select(:id), event: %w[create update])
                                   .where.not(whodunnit: @user.id.to_s).order(created_at: :desc, id: :desc).limit(LIMITE).to_a
      avaliacoes = @visiveis.where(id: versoes.map(&:item_id)).includes(setor: :instituicao).index_by(&:id)
      autores = User.where(id: versoes.filter_map { |versao| Integer(versao.whodunnit.to_s, exception: false) }).index_by(&:id)
      versoes.filter_map do |versao|
        avaliacao = avaliacoes[versao.item_id] or next
        Item.new(quando: versao.created_at, acao: versao.event == "create" ? :registrou : :atualizou,
                 autor: autores[Integer(versao.whodunnit.to_s, exception: false)], avaliacao:)
      end
    end
  end
end
