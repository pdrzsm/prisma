# Pacientes aparecem pelas notificações: a pessoa vê um paciente quando vê
# alguma notificação dele.
#
# Corrigir a identificação (prontuários e iniciais; LGPD, art. 18, III) muda o
# que aparece em todas as notificações do paciente. Por isso exige registrar
# cada formulário em que ele tem notificação, no setor dela: ninguém altera o
# que aparece numa notificação que não pode editar, e quem só consulta não
# corrige. edit? segue update?; ver, criar e excluir continuam negados.
class PacientePolicy < ApplicationPolicy
  def update?
    pares = record.avaliacoes_clinicas.distinct.pluck(:setor_id, :formulario)
    pares.any? && pares.all? { |setor_id, formulario| user.permissoes.registra?(setor_id, formulario) }
  end

  # Só os pacientes das notificações que a pessoa vê
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(id: user.permissoes.escopo_de_avaliacoes(AvaliacaoClinica).select(:paciente_id))
    end
  end
end
