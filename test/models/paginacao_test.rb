require "test_helper"

class PaginacaoTest < ActiveSupport::TestCase
  def paginacao(pagina, total: 50, por_pagina: 15)
    Paginacao.new(pagina, por_pagina:, total:)
  end

  test "o intervalo e o deslocamento seguem a página" do
    primeira = paginacao("1")
    assert_equal [ 4, 0, 1, 15 ], [ primeira.paginas, primeira.deslocamento, primeira.primeiro, primeira.ultimo ]

    ultima = paginacao("4")
    assert_equal [ 45, 46, 50 ], [ ultima.deslocamento, ultima.primeiro, ultima.ultimo ]
    assert ultima.anterior?
    assert_not ultima.proxima?
  end

  test "a primeira página não tem anterior e uma lista só não tem várias páginas" do
    assert_not paginacao("1").anterior?
    assert paginacao("1").proxima?

    uma = paginacao("1", total: 15)
    assert_equal 1, uma.paginas
    assert_not uma.varias?
    assert_not uma.proxima?

    assert_equal 1, paginacao("1", total: 0).paginas
  end

  test "o que não é um inteiro decimal positivo vira a primeira página" do
    [ nil, "", "abc", "0", "-3", "1.5", "0x10", "1e3", [ "3" ], { "a" => "3" }, ActionController::Parameters.new(a: "3") ].each do |valor|
      assert_equal 1, paginacao(valor).pagina, valor.inspect
    end
  end

  test "o número é lido em base 10, com ou sem zeros à esquerda" do
    assert_equal 2, paginacao("02").pagina
    assert_equal 10, paginacao("010", total: 200).pagina
  end

  test "depois da última página, fica na seguinte a ela, que vem vazia, sem estourar o banco" do
    [ "5", "999999", "9" * 40 ].each do |valor|
      depois = paginacao(valor)
      assert_equal 5, depois.pagina, valor
      assert_operator depois.deslocamento, :>=, depois.total
    end
  end

  test "os números mostram a primeira, a última e a atual com uma vizinha de cada lado" do
    assert_equal [ 1, 2, 3, 4 ], paginacao("2").numeros
    assert_equal [ 1, :lacuna, 4, 5, 6, :lacuna, 20 ], paginacao("5", total: 300).numeros
    assert_equal [ 1, 2, :lacuna, 20 ], paginacao("1", total: 300).numeros
    assert_equal [ 1, :lacuna, 19, 20 ], paginacao("20", total: 300).numeros
  end

  test "um buraco de uma página só mostra a própria página, em vez de reticências" do
    assert_equal [ 1, 2, 3, 4, 5, 6, 7 ], paginacao("4", total: 105).numeros
    assert_equal [ 1, 2, 3, :lacuna, 7 ], paginacao("2", total: 105).numeros
    assert_equal [ 1 ], paginacao("1", total: 0).numeros
  end
end
