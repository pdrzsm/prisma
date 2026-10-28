require "test_helper"

# Relatórios e indicadores: números só das notificações liberadas, sem dado de paciente
class RelatoriosTest < ActionDispatch::IntegrationTest
  test "quem consulta vê os indicadores do formulário, sem iniciais nem prontuários" do
    sign_in users(:consultor)
    get relatorios_path

    assert_response :success
    assert_select "nav[aria-label='Seções do sistema'] a[aria-current='page']", text: "Relatórios"
    assert_select "#base_atual", text: /Acompanhamento de teste/
    assert_select "dt", text: /Registradas/
    assert_select "table th", text: "Iniciais", count: 0
  end

  test "o admin vê todas as unidades, e o período e a unidade filtram" do
    sign_in users(:admin)
    get relatorios_path(periodo: 3)

    assert_response :success
    assert_select "#periodo_atual", text: "Últimos 3 meses"
    assert_select "#unidade_atual", text: "Todas as minhas unidades"
  end

  test "sem liberação, avisa" do
    sign_in users(:sem_acesso)
    get relatorios_path

    assert_response :success
    assert_select "div", text: /nenhum formulário liberado/
  end

  test "o índice calcula situação, taxa e paradas das notificações do período" do
    formulario = Formulario.publicado!("acompanhamento")
    indicadores = IndicadoresDoFormulario.new(AvaliacaoClinica.where(formulario: formulario.chave), formulario:, meses: 12)

    assert_equal indicadores.total, indicadores.encerradas.size + indicadores.em_acompanhamento.size
    assert_operator indicadores.por_mes.size, :==, 12
  end
end
