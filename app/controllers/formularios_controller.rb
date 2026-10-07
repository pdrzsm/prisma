# Seção "Formulários" do menu: os formulários que a pessoa consulta em pelo
# menos um setor (o admin vê todos), com o total de registros que ela vê
class FormulariosController < ApplicationController
  def index
    authorize :formulario
    @formularios = Formulario.todos.select { |formulario| current_user.permissoes.consulta_o_formulario?(formulario.chave) }
    @totais = policy_scope(AvaliacaoClinica).group(:formulario).count
  end
end
