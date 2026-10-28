# Um formulário (ver Formulario) habilitado num setor da instituição dele pelo
# admin, no gerador ou na tela do setor. Só nos setores em que está habilitado
# o formulário pode ser liberado para alguém e receber notificações, e só
# depois de publicado (Permissoes ignora o que ainda é rascunho).
class FormularioHabilitado < ApplicationRecord
  belongs_to :setor, inverse_of: :formularios_habilitados
  has_paper_trail

  validates :formulario, uniqueness: { scope: :setor_id }
  # Na criação: um setor de outra instituição que já tinha o formulário antes
  # da regra (migração de 2026-10-09) continua com ele
  validate :formulario_da_instituicao_do_setor, on: :create

  # Registro clínico é preservado: um formulário com notificações no setor não
  # sai do setor, ou elas ficariam sem quem as veja
  before_destroy :manter_se_tem_notificacoes

  private

  def formulario_da_instituicao_do_setor
    dono = Formulario.find_by(chave: formulario)
    if dono.nil?
      errors.add(:formulario, "não existe")
    elsif setor && dono.instituicao_id != setor.instituicao_id
      errors.add(:formulario, "é de outra instituição")
    end
  end

  def manter_se_tem_notificacoes
    return unless AvaliacaoClinica.exists?(setor_id:, formulario:)

    titulo = Formulario.find_by(chave: formulario)&.titulo || formulario
    errors.add(:base, "#{titulo} tem notificações neste setor e não pode ser desabilitado")
    throw :abort
  end
end
