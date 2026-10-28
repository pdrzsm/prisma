# Modo claro ou noturno, guardado num cookie do navegador (sem JavaScript: o
# botão do topo envia o formulário e o layout põe data-tema no <html>).
class TemasController < ApplicationController
  MODOS = %w[claro escuro].freeze

  def update
    authorize :tema
    modo = params[:modo].to_s
    cookies.permanent[:tema] = { value: modo, httponly: true, same_site: :lax } if MODOS.include?(modo)
    redirect_back_or_to root_path, status: :see_other
  end
end
