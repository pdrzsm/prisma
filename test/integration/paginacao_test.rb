require "test_helper"

# O rodapé da tabela de notificações (shared/_paginacao), nas duas listas: a do
# formulário (/formularios/:chave/avaliacoes) e a de Formulários (/formularios),
# cada uma com o seu tamanho de página.
class PaginacaoIntegrationTest < ActionDispatch::IntegrationTest
  FORMULARIO = "acompanhamento".freeze
  POR_PAGINA = { avaliacoes: AvaliacoesClinicasController::POR_PAGINA, formularios: FormulariosController::LIMITE }.freeze

  def lista(qual, **filtros)
    if qual == :avaliacoes
      formulario_avaliacoes_clinicas_path(FORMULARIO, **filtros)
    else
      formularios_path(unidade: setores(:ambulatorio).id, formulario: FORMULARIO, **filtros)
    end
  end

  # Cria notificações no Ambulatório até ele ter o total dado (as 2 das fixtures contam)
  def registrar_ate(total)
    (total - AvaliacaoClinica.where(setor: setores(:ambulatorio)).count).times do |indice|
      paciente = Paciente.create!(setor: setores(:ambulatorio), iniciais: "PG", prontuario_sah: "SAH-PG#{indice}")
      AvaliacaoClinica.create!(paciente:, setor: setores(:ambulatorio), user: users(:operador), formulario: FORMULARIO,
                               dados_formulario: respostas_de_abertura)
    end
  end

  test "as páginas são de 14 notificações em Formulários e de 15 na lista de cada formulário" do
    assert_equal({ avaliacoes: 15, formularios: 14 }, POR_PAGINA)
  end

  POR_PAGINA.each do |qual, por_pagina|
    test "#{qual}: uma página só mostra a contagem, sem os botões" do
      sign_in users(:consultor)

      get lista(qual)
      assert_response :success
      assert_select "p", text: /\A\s*2 notificações\s*\z/
      assert_select "nav[aria-label='Paginação']", 0
    end

    test "#{qual}: com mais de uma página mostra o intervalo, os números e os vizinhos" do
      total = por_pagina + 1
      registrar_ate(total)
      sign_in users(:consultor)

      get lista(qual)
      assert_select "p", text: /Mostrando 1 a #{por_pagina} de #{total} notificações/
      assert_select "tbody tr", por_pagina
      assert_select "nav[aria-label='Paginação']" do
        assert_select "[aria-current='page']", text: /1/
        assert_select "a[aria-label='Página 2'][href*='pagina=2']"
        assert_select "a[rel=next][href*='pagina=2']", text: /Próxima/
        # Na primeira, o Anterior não é link
        assert_select "a[rel=prev]", 0
        assert_select "span[aria-disabled=true]", text: /Anterior/
      end

      get lista(qual), params: { pagina: 2 }
      assert_select "p", text: /Mostrando #{total} de #{total} notificações/
      assert_select "tbody tr", 1
      assert_select "nav[aria-label='Paginação']" do
        assert_select "[aria-current='page']", text: /2/
        assert_select "a[rel=prev]", text: /Anterior/
        assert_select "span[aria-disabled=true]", text: /Próxima/
        assert_select "a[rel=next]", 0
      end
    end

    test "#{qual}: cada notificação aparece em uma página só, sem repetir nem faltar" do
      total = por_pagina + 1
      registrar_ate(total)
      # Todas com a mesma hora de atualização: só o id as separa
      AvaliacaoClinica.update_all(updated_at: Time.zone.parse("2026-01-02 10:00"))
      sign_in users(:consultor)

      # A segunda coluna é o prontuário SAH, único em cada linha
      vistas = [ 1, 2 ].flat_map do |pagina|
        get lista(qual), params: { pagina: }
        css_select("tbody tr td:nth-child(2)").map { |celula| celula.text.strip }
      end

      assert_equal total, vistas.size
      assert_equal total, vistas.uniq.size
    end

    test "#{qual}: a busca vale para a contagem, e a primeira página volta sem número na URL" do
      total = por_pagina + 1
      registrar_ate(total)
      sign_in users(:consultor)

      # As criadas combinam com "SAH-PG"; as 2 das fixtures ficam de fora
      get lista(qual, prontuario: "SAH-PG")
      assert_select "p", text: /\A\s*#{total - 2} notificações\s*\z/
      assert_select "nav[aria-label='Paginação']", 0

      # "SAH-" combina com todas: o Anterior e o número 1 levam à lista filtrada, sem pagina=
      sem_numero = lista(qual, prontuario: "SAH-")
      get sem_numero, params: { pagina: 2 }
      assert_select "a[rel=prev][href=?]", sem_numero
      assert_select "a[aria-label='Página 1'][href=?]", sem_numero
    end

    test "#{qual}: uma página depois da última avisa e leva de volta à primeira, mantendo a busca" do
      sign_in users(:consultor)

      get lista(qual, prontuario: "MFU"), params: { pagina: 999_999 }
      assert_response :success
      assert_includes response.body, "Não há registros nesta página"
      assert_select "a[href=?]", lista(qual, prontuario: "MFU"), text: "Voltar à primeira página"
      assert_select "nav[aria-label='Paginação']", 0
    end

    test "#{qual}: qualquer valor na página vira a primeira, até uma lista ou um número enorme" do
      sign_in users(:consultor)

      [ { pagina: [ "2" ] }, { pagina: { x: 1 } }, { pagina: "9" * 40 }, { pagina: "-1" } ].each do |parametros|
        get lista(qual), params: parametros
        assert_response :success, parametros.to_s
      end
    end
  end
end
