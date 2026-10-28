require "test_helper"

# O menu lateral (shared/_menu): todo item é uma tela, e os grupos têm um
# rótulo que não é link
class MenuTest < ActionDispatch::IntegrationTest
  MENU = "nav[aria-label='Seções do sistema']".freeze

  test "Formulários é um item do menu, que fica ativo nos registros de um formulário" do
    sign_in users(:consultor)
    get formulario_avaliacoes_clinicas_path("acompanhamento")

    assert_select MENU do
      assert_select "a[aria-current='page']", text: "Formulários"
      assert_select "a", text: "Visão geral"
      assert_select "a", text: "Acompanhamento de teste", count: 0
    end
    # Na trilha, Formulários leva à página das unidades
    assert_select "nav[aria-label='Você está em']" do
      assert_select "a[href='#{formularios_path}']", text: "Formulários"
      assert_select "[aria-current='page']", text: "Acompanhamento de teste"
    end
  end

  test "sem liberação, o item Formulários não aparece" do
    sign_in users(:sem_acesso)
    get root_path

    assert_select "#{MENU} a", text: "Formulários", count: 0
  end

  test "a página Formulários tem um menu de unidades e, nela, as bases liberadas" do
    sign_in users(:consultor)
    get formularios_path

    assert_response :success
    assert_select "#unidade_atual", text: /-/
    assert_select "details ul a[href*='unidade='][aria-current='page']", 2
    assert_select "table tbody tr"
    assert_select "#base_atual", text: /Acompanhamento de teste/
    assert_select "a[href*='filtros=1']"
    assert_select "a", text: "Abrir busca completa", count: 0
  end

  test "a página Formulários, sem liberação, avisa" do
    sign_in users(:sem_acesso)
    get formularios_path

    assert_response :success
    assert_select "#unidade_atual", count: 0
    assert_select "div", text: /nenhum formulário liberado/
  end

  test "as telas de dentro têm Voltar para o nível de cima; as de primeiro nível, não" do
    sign_in users(:consultor)
    get formulario_avaliacoes_clinicas_path("acompanhamento")
    assert_select "header a[aria-label='Voltar para Formulários'][href='#{formularios_path}']"

    get formularios_path
    assert_select "header a[aria-label^='Voltar']", count: 0
  end

  test "a barra lateral é só navegação: conta, avisos e busca ficam no cabeçalho" do
    sign_in users(:consultor)
    get root_path

    assert_select "aside #{MENU} a", text: /Novidades|Avisos|Modo noturno|Sair/, count: 0
    assert_select "header form[role=search][action='#{buscas_path}']"
    assert_select "header summary[aria-label='Avisos']"
    assert_select "header summary[title='Minha conta']"
  end

  test "Configurações é só do admin e fica no pé do menu, longe dos itens do dia a dia" do
    sign_in users(:admin)
    get root_path
    assert_select "aside #{MENU} > div.mt-auto" do
      assert_select "p", text: "Configurações"
      assert_select "a", 3
    end
    assert_select "aside #{MENU} > ul a", text: /Instituições e setores|Usuários|Gerador de formulários/, count: 0

    sign_in users(:consultor)
    get root_path
    assert_select "aside #{MENU} p", text: "Configurações", count: 0
    assert_select "aside #{MENU} > div.mt-auto", count: 0
  end

  test "o item do menu da página atual é um só (o gerador não acende Formulários)" do
    sign_in users(:admin)
    get configuracoes_formularios_path

    assert_select "aside #{MENU} a[aria-current='page']", count: 1
    assert_select "aside #{MENU} a[aria-current='page']", text: /Gerador de formulários/
  end

  test "a notificação tem o botão Imprimir, e o resto da tela some na impressão" do
    sign_in users(:consultor)
    get formulario_avaliacao_clinica_path("acompanhamento", avaliacoes_clinicas(:two))

    assert_response :success
    assert_select "button[data-imprimir]", text: /Imprimir/
    assert_select "aside.print\\:hidden"
    assert_select "header.print\\:hidden"
    assert_select "p.print\\:block", text: /impresso por @#{users(:consultor).username}/
  end

  test "os filtros da lista abrem num painel lateral, e Limpar volta à lista inteira" do
    sign_in users(:consultor)
    lista = formulario_avaliacoes_clinicas_path("acompanhamento")

    get lista
    assert_select "a[href*='filtros=1']", text: /Filtros/
    assert_select "dialog[open]", count: 0

    get lista, params: { filtros: 1, prontuario: "123" }
    assert_select "dialog[open][aria-label='Filtros'] form[role=search] input[name=prontuario]"
    assert_select "dialog a[href='#{lista}']", text: "Limpar"
    assert_select "a[aria-label='Tirar a busca']"
  end
end
