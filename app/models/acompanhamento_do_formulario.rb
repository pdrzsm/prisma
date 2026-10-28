# O que acontece com um formulário em cada setor, para o admin acompanhar na
# tela do formulário (Configurações > Gerador de formulários):
#
# - movimento: em cada setor em que ele está, quantas notificações tem, a data
#   do último registro e se o setor está parado (publicado e sem registro há
#   mais de DIAS_PARADO dias);
# - historico: quem incluiu ou tirou o formulário de cada setor, e quando,
#   lido da auditoria (PaperTrail) de FormularioHabilitado.
#
# Só números e datas: nenhuma resposta nem dado de paciente.
class AcompanhamentoDoFormulario
  DIAS_PARADO = 30

  Movimento = Data.define(:notificacoes, :ultimo_registro, :parado)
  Evento = Data.define(:quando, :acao, :setor, :autor)

  def initialize(formulario)
    @formulario = formulario
  end

  # { setor_id => Movimento }, só dos setores em que o formulário está
  def movimento
    @movimento ||= begin
      registros = AvaliacaoClinica.where(formulario: @formulario.chave).group(:setor_id)
      contagens = registros.count
      ultimos = registros.maximum(:created_at)
      @formulario.habilitacoes.to_h do |habilitacao|
        ultimo = ultimos[habilitacao.setor_id]
        [ habilitacao.setor_id,
          Movimento.new(notificacoes: contagens.fetch(habilitacao.setor_id, 0), ultimo_registro: ultimo,
                        parado: parado?(ultimo || [ habilitacao.created_at, primeira_publicacao ].compact.max)) ]
      end
    end
  end

  # Inclusões e retiradas do formulário nos setores, da mais recente para a
  # mais antiga
  def historico
    versoes = PaperTrail::Version.where(item_type: "FormularioHabilitado", event: %w[create destroy])
                                 .where("object LIKE :chave OR object_changes LIKE :chave",
                                        chave: "%#{ActiveRecord::Base.sanitize_sql_like(@formulario.chave)}%")
                                 .order(created_at: :desc, id: :desc)
    eventos = versoes.filter_map do |versao|
      dados = dados_da_versao(versao)
      next unless dados && dados["formulario"] == @formulario.chave

      [ versao, dados["setor_id"] ]
    end
    setores = Setor.includes(:instituicao).where(id: eventos.map(&:last)).index_by(&:id)
    autores = User.where(id: eventos.filter_map { |versao, _| Integer(versao.whodunnit.to_s, exception: false) }).index_by(&:id)

    eventos.map do |versao, setor_id|
      Evento.new(quando: versao.created_at, acao: versao.event == "create" ? :incluiu : :tirou,
                 setor: setores[setor_id], autor: autores[Integer(versao.whodunnit.to_s, exception: false)])
    end
  end

  private

  def parado?(desde)
    @formulario.publicado? && desde.present? && desde < DIAS_PARADO.days.ago
  end

  def primeira_publicacao
    @primeira_publicacao ||= @formulario.versoes.where.not(publicada_em: nil).minimum(:publicada_em)
  end

  # O setor e o formulário da auditoria: na inclusão, vêm nas mudanças
  # (object_changes, [antes, depois]); na retirada, no registro como estava
  # (object). O YAML só aceita as classes de data que o PaperTrail grava.
  def dados_da_versao(versao)
    if versao.event == "create"
      mudancas = carregar(versao.object_changes)
      mudancas&.transform_values { |(_, depois)| depois }
    else
      carregar(versao.object)
    end
  end

  def carregar(yaml)
    return if yaml.blank?

    dados = YAML.safe_load(yaml, permitted_classes: [ Time, Date, Symbol ], aliases: false)
    dados if dados.is_a?(Hash)
  rescue Psych::Exception
    nil
  end
end
