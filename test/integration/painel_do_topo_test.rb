require "test_helper"

# Os menus suspensos do cabeçalho, a janela de troca de senha (?painel=senha)
# e o modo noturno
class PainelDoTopoTest < ActionDispatch::IntegrationTest
  test "novidades, avisos e a conta são menus suspensos do cabeçalho, sem JavaScript" do
    sign_in users(:consultor)
    get formularios_path

    assert_select "header details[name='menu_do_topo']", 3
    assert_select "header details summary[aria-label='Novidades'] + div p", text: "Novidades"
    assert_select "header details summary[aria-label='Avisos'] + div p", text: "Avisos"
    assert_select "header details summary[title='Minha conta'] + div" do
      assert_select "a[href*='painel=senha']", text: /Trocar senha/
      assert_select "form[action='#{destroy_user_session_path}'] button", text: /Sair/
    end
    assert_select "dialog[open]", count: 0
  end

  test "só a troca de senha abre janela; outro ?painel= não abre nada" do
    sign_in users(:consultor)

    get formularios_path(painel: "senha")
    assert_select "dialog[open][aria-label='Trocar senha']"

    %w[novidades avisos conta configuracoes].each do |painel|
      get formularios_path(painel:)
      assert_select "dialog[open]", { count: 0 }, painel
    end
  end

  test "o modo noturno fica num cookie e o layout o aplica" do
    sign_in users(:consultor)
    get root_path
    assert_select "html[data-tema='claro']"

    patch tema_path(modo: "escuro")
    follow_redirect!
    assert_select "html[data-tema='escuro']"

    patch tema_path(modo: "qualquer")
    follow_redirect!
    assert_select "html[data-tema='escuro']"
  end
end
