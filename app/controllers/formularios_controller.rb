# Seção "Formulários" do menu: os formulários clínicos disponíveis
class FormulariosController < ApplicationController
  def index
    authorize :formulario
    @formularios = Formulario.todos
    @totais = policy_scope(AvaliacaoClinica).group(:formulario).count
  end
end
