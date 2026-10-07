# Notificações: quem vê e quem registra vem das liberações (Permissoes), por
# setor e formulário. O record é uma notificação gravada ou uma nova, montada
# com o formulário (e o setor, ao gravar) para as telas de lista e de registro:
#   authorize AvaliacaoClinica.new(formulario: "seguimento_tb")
class AvaliacaoClinicaPolicy < ApplicationPolicy
  # Lista do formulário: consulta em pelo menos um setor
  def index?
    permissoes.consulta_o_formulario?(record.formulario)
  end

  # Ver: consulta no setor da notificação
  def show?
    permissoes.consulta?(record.setor_id, record.formulario)
  end

  # Tela de nova notificação: registra o formulário em pelo menos um setor
  def new?
    permissoes.registra_o_formulario?(record.formulario)
  end

  # Gravar: registra o formulário no setor escolhido
  def create?
    permissoes.registra?(record.setor_id, record.formulario)
  end

  # O seguimento é atualizado ao longo do tratamento por quem registra no setor;
  # cada alteração fica na auditoria (PaperTrail). edit? segue update?.
  def update?
    create?
  end

  # destroy? continua negado (herdado): registro clínico não é apagado

  # Só as notificações dos pares (setor, formulário) liberados
  class Scope < ApplicationPolicy::Scope
    def resolve
      user.permissoes.escopo_de_avaliacoes(scope)
    end
  end

  private

  def permissoes
    user.permissoes
  end
end
