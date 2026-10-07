require "application_system_test_case"

class AvisosNavegadorTest < ApplicationSystemTestCase
  test "o aviso fecha pelo botão, sem JavaScript" do
    sign_in users(:admin)
    visit root_path
    click_on "Sair"

    assert_current_path new_user_session_path
    within("dialog.aviso") { assert_text "Você saiu do sistema." }

    find("button[aria-label='Fechar aviso']").click
    assert_no_selector "dialog.aviso"
    assert_no_text "Você saiu do sistema."
  end
end
