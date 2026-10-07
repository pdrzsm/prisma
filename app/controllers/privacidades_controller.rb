# Privacidade e proteção de dados: para que o Prisma coleta dados, com qual
# base legal, quem acessa, por quanto tempo ficam guardados e como os direitos
# dos titulares são atendidos (LGPD, art. 9º). Ligada no rodapé de todas as
# telas. Exige login, como todo o sistema.
class PrivacidadesController < ApplicationController
  def show
    authorize :privacidade
    @formularios = Formulario.todos
    @encarregado = Rails.configuration.x.encarregado
  end
end
