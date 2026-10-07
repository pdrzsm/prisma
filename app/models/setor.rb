# Um setor de uma instituição (ex.: um ambulatório ou uma unidade). Cadastrado
# pelo admin em Configurações, dentro da instituição. Cada setor tem os seus
# pacientes e notificações, e os formulários que o admin habilitar nele.
class Setor < ApplicationRecord
  belongs_to :instituicao, inverse_of: :setores
  # Registro clínico é preservado: setor com pacientes não é excluído
  has_many :pacientes, dependent: :restrict_with_error
  has_many :avaliacoes_clinicas, dependent: :restrict_with_error
  # Configuração do setor: sai junto com ele (e fica na auditoria)
  has_many :formularios_habilitados, -> { order(:formulario) }, dependent: :destroy, inverse_of: :setor
  has_many :liberacoes_setor, class_name: "LiberacaoSetor", dependent: :destroy
  has_many :liberacoes_formulario, class_name: "LiberacaoFormulario", dependent: :destroy
  has_paper_trail

  normalizes :nome, with: ->(nome) { nome.squish }

  # O mesmo nome pode se repetir em outra instituição, nunca na mesma
  validates :nome, presence: true, length: { maximum: 150 },
                   uniqueness: { scope: :instituicao_id, case_sensitive: false }

  # Chaves dos formulários habilitados neste setor
  def formularios
    formularios_habilitados.map(&:formulario)
  end

  # Como o setor aparece fora de Configurações: "SIGLA - Setor" (ou o nome da
  # instituição, se ela não tiver sigla), como na trilha do layout
  def nome_completo
    "#{instituicao.sigla || instituicao.nome} - #{nome}"
  end

  # Deixa habilitados exatamente estes formulários. Desabilitar tira também as
  # liberações do formulário no setor; um formulário com notificações no setor
  # não é desabilitado (o erro vai para errors). Devolve true se deu tudo certo.
  def habilitar_formularios(chaves)
    chaves = Array(chaves).map(&:to_s) & Formulario.chaves
    transaction do
      formularios_habilitados.reject { |habilitado| chaves.include?(habilitado.formulario) }.each do |habilitado|
        habilitado.destroy ? liberacoes_formulario.where(formulario: habilitado.formulario).destroy_all : errors.merge!(habilitado.errors)
      end
      (chaves - formularios).each { |chave| formularios_habilitados.create!(formulario: chave) }
    end
    formularios_habilitados.reset
    errors.empty?
  end
end
