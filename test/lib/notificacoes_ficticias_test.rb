require "test_helper"

class NotificacoesFicticiasTest < ActiveSupport::TestCase
  # Data fixa: com a mesma semente, o sorteio dá sempre o mesmo resultado
  HOJE = Date.new(2026, 1, 15)

  setup { @existentes = AvaliacaoClinica.ids }

  test "gera notificações válidas, abertas e encerradas, com histórico" do
    assert_equal 30, gerar(30)
    geradas = AvaliacaoClinica.where.not(id: @existentes).includes(:paciente, :versions).to_a

    assert_equal 30, geradas.size
    assert geradas.all?(&:valid?)
    assert geradas.any?(&:encerrada?)
    assert geradas.any? { |avaliacao| !avaliacao.encerrada? }
    assert geradas.all? { |avaliacao| avaliacao.paciente.prontuario_sah.start_with?("TESTE-SAH-") }
    assert geradas.all? { |avaliacao| avaliacao.setor == setores(:ambulatorio) && avaliacao.paciente.setor == setores(:ambulatorio) }
    assert geradas.all? { |avaliacao| avaliacao.created_at.to_date <= HOJE && avaliacao.updated_at >= avaliacao.created_at }

    # Cada etapa (abertura, meses, encerramento) é uma versão, com autor
    encerradas = geradas.select(&:encerrada?)
    assert encerradas.all? { |avaliacao| avaliacao.versions.size >= 2 }
    autores = [ users(:operador), users(:admin) ].map { |user| user.id.to_s }
    assert geradas.flat_map(&:versions).all? { |versao| autores.include?(versao.whodunnit) }
  end

  test "rodar de novo não duplica" do
    gerar(5)

    assert_no_difference -> { AvaliacaoClinica.count } do
      assert_equal 0, gerar(5)
    end
    assert_equal 2, gerar(7)
  end

  test "não roda em produção" do
    Rails.env = "production"
    assert_raises(RuntimeError) { gerar(1) }
  ensure
    Rails.env = "test"
  end

  private

  def gerar(quantidade)
    NotificacoesFicticias.new(quantidade:, autores: [ users(:operador), users(:admin) ], setor: setores(:ambulatorio), hoje: HOJE).gerar
  end
end
