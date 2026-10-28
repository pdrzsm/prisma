# Troca da própria senha. É obrigatória no primeiro acesso e depois que o
# admin redefine a senha (deve_trocar_senha): nesses casos, é a única tela que
# abre (ver ApplicationController#exigir_troca_de_senha). Sempre a senha do
# current_user: não há como trocar a de outra pessoa por aqui.
#
# Pela janela do cabeçalho (senhas/_janela, com o campo "voltar": a página que
# estava atrás dela), um erro volta para essa mesma página com a janela aberta
# de novo (?painel=senha), as mensagens nos campos e um código novo; o acerto
# também volta para ela. Pela tela de troca (senhas/edit), o erro redesenha a
# tela.
class SenhasController < ApplicationController
  # A senha atual é conferida a cada tentativa, e o :lockable do Devise não
  # conta as erradas aqui: o limite impede adivinhá-la numa sessão sequestrada
  rate_limit to: 10, within: 10.minutes, only: :update, by: -> { current_user.id },
             with: -> { redirect_to edit_senha_path, alert: "Muitas tentativas de troca de senha. Aguarde alguns minutos.", status: :see_other }

  def edit
    authorize :senha
  end

  def update
    authorize :senha
    nova = senha_params[:password].to_s

    # O código mostrado com os campos (CodigoDeConfirmacao) vem antes de tudo:
    # sem ele, nada é conferido, nem a senha atual. Sem as outras checagens, o
    # Devise aceitaria "nova senha" em branco (e só apagaria a obrigação de
    # trocar) ou a mesma senha de antes
    if !CodigoDeConfirmacao.new(session, :troca_de_senha).confere?(params.dig(:usuario, :codigo))
      current_user.errors.add(:codigo, "não confere com o código mostrado (digite o novo código)")
    elsif nova.blank?
      current_user.errors.add(:password, :blank)
    elsif current_user.valid_password?(nova)
      current_user.errors.add(:password, "precisa ser diferente da senha atual")
    elsif current_user.update_with_password(senha_params.merge(deve_trocar_senha: false))
      # Trocar a senha invalida as sessões abertas; esta continua
      bypass_sign_in(current_user)
      return redirect_to(pagina_de_volta || root_path, notice: "Senha alterada.", status: :see_other)
    end

    if (pagina = pagina_de_volta)
      # Só as mensagens (nunca as senhas digitadas), para a janela mostrar de novo
      flash[:erros_da_troca_de_senha] = current_user.errors.to_hash.transform_keys(&:to_s)
      return redirect_to(com_a_janela_aberta(pagina), status: :see_other)
    end

    flash.now[:alert] = "Não foi possível trocar a senha. Revise os campos destacados."
    render :edit, status: :unprocessable_content
  end

  private

  def senha_params
    params.expect(usuario: [ :current_password, :password, :password_confirmation ])
  end

  # A página atrás da janela, se o pedido veio dela: só um caminho deste
  # próprio sistema (nada de outro endereço). Na troca obrigatória, não há
  # para onde voltar: a única tela que abre é a de troca.
  def pagina_de_volta
    return if current_user.deve_trocar_senha?

    caminho = params[:voltar].to_s
    uri = URI.parse(caminho)
    caminho if caminho.start_with?("/") && !caminho.start_with?("//") && uri.scheme.nil? && uri.host.nil?
  rescue URI::InvalidURIError
    nil
  end

  def com_a_janela_aberta(caminho)
    uri = URI.parse(caminho)
    consulta = Rack::Utils.parse_nested_query(uri.query).merge("painel" => "senha")
    "#{uri.path}?#{consulta.to_query}"
  end
end
