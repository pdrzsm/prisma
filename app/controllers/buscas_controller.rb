# Busca global por prontuário (SAH ou AGHUSE) ou iniciais, em todas as
# notificações que a pessoa consulta — de qualquer formulário e setor, não só
# o de uma lista. Mesma busca de dentro de um formulário (AvaliacoesClinicasController,
# Paciente.ids_que_combinam), só que sem escolher o formulário antes: o campo
# fica no header (shared/_topo). Mostra dado sensível: auditoria de leitura,
# como o index de cada formulário.
class BuscasController < ApplicationController
  POR_PAGINA = 30

  def index
    @termo = params[:termo].to_s.strip
    registros = policy_scope(AvaliacaoClinica)
    @avaliacoes =
      if @termo.present?
        registros.where(paciente_id: Paciente.ids_que_combinam(registros, @termo))
                 .includes(:paciente, :user, setor: :instituicao)
                 .order(updated_at: :desc)
                 .limit(POR_PAGINA)
                 .to_a
      else
        []
      end
    log_read_access(@avaliacoes)
  end
end
