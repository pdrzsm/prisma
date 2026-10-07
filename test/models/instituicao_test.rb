require "test_helper"

class InstituicaoTest < ActiveSupport::TestCase
  test "limpa espaços, põe a sigla em maiúsculas e sigla vazia vira nil" do
    instituicao = Instituicao.create!(nome: "  Instituto   Teste ", sigla: " it ")

    assert_equal "Instituto Teste", instituicao.nome
    assert_equal "IT", instituicao.sigla
    assert_nil Instituicao.create!(nome: "Sem Sigla", sigla: "  ").sigla
  end

  test "nome e sigla não repetem, sem diferenciar maiúsculas" do
    repetida = Instituicao.new(nome: "hospital exemplo", sigla: "crf")

    assert_not repetida.valid?
    assert_includes repetida.errors[:nome], "já está em uso"
    assert_includes repetida.errors[:sigla], "já está em uso"
  end

  test "várias instituições podem ficar sem sigla" do
    assert_nil instituicoes(:hospital).sigla
    assert Instituicao.create(nome: "Outra sem sigla").persisted?
  end

  test "nome é obrigatório e tem limite" do
    assert_not Instituicao.new(nome: " ").valid?
    assert_not Instituicao.new(nome: "a" * 151).valid?
    assert_not Instituicao.new(nome: "Ok", sigla: "a" * 21).valid?
  end

  test "não exclui instituição com setores" do
    centro = instituicoes(:centro)

    assert_not centro.destroy
    assert_equal [ "Não é possível excluir enquanto houver setores" ], centro.errors.full_messages
    assert Instituicao.exists?(centro.id)
  end

  test "setores vêm em ordem alfabética" do
    assert_equal %w[Ambulatório Laboratório], instituicoes(:centro).setores.map(&:nome)
  end

  test "toda alteração fica na auditoria" do
    instituicao = Instituicao.create!(nome: "Auditada")
    instituicao.update!(sigla: "AUD")
    instituicao.destroy!

    assert_equal %w[create update destroy], PaperTrail::Version.where(item_type: "Instituicao", item_id: instituicao.id).order(:id).pluck(:event)
  end
end
