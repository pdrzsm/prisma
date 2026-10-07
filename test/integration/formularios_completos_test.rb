require "test_helper"

# Preenche todas as perguntas de cada formulário de config/formularios, com
# respostas geradas a partir da própria definição: vale para os formulários
# que ainda vão existir, não só para o de TB.
class FormulariosCompletosTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:operador) }

  Formulario.todos.each do |formulario|
    test "#{formulario.chave}: registra, mostra e edita todas as perguntas" do
      respostas = respostas_completas(formulario)
      esperado = formulario.normalizar(respostas)

      assert_difference "AvaliacaoClinica.count", 1 do
        post formulario_avaliacoes_clinicas_path(formulario), params: {
          paciente: { prontuario_sah: "SAH-COMPLETO", prontuario_aghuse: "AGH-COMPLETO", iniciais: "ABC" },
          avaliacao_clinica: { setor_id: setores(:ambulatorio).id, dados_formulario: respostas }
        }
      end
      avaliacao = AvaliacaoClinica.last
      assert_redirected_to formulario_avaliacao_clinica_path(formulario, avaliacao)
      assert_equal formulario.perguntas_de_resposta.map(&:chave).sort, esperado.keys.sort, "toda pergunta respondida"
      assert_equal esperado, avaliacao.reload.respostas

      get formulario_avaliacao_clinica_path(formulario, avaliacao)
      formulario.perguntas_de_resposta.each do |pergunta|
        texto = ERB::Util.html_escape(formulario.resposta_formatada(pergunta, esperado[pergunta.chave]))
        assert_includes response.body, texto, "resposta da pergunta #{pergunta.numero} na visualização"
      end

      get edit_formulario_avaliacao_clinica_path(formulario, avaliacao)
      formulario.perguntas_de_resposta.each { |pergunta| assert_campo_preenchido(pergunta, esperado[pergunta.chave]) }
      assert_html_acessivel

      # Reenviar a edição sem mudar nada não cria versão nem conflito
      assert_no_difference -> { avaliacao.versions.count } do
        patch formulario_avaliacao_clinica_path(formulario, avaliacao), params: {
          avaliacao_clinica: { lock_version: avaliacao.reload.lock_version, dados_formulario: respostas }
        }
      end
      assert_redirected_to formulario_avaliacao_clinica_path(formulario, avaliacao)
    end

    test "#{formulario.chave}: tela de registro tem um campo com rótulo para cada pergunta" do
      get new_formulario_avaliacao_clinica_path(formulario)

      assert_response :success
      assert_select ".pergunta", formulario.perguntas.size
      assert_html_acessivel
    end
  end

  private

  def respostas_completas(formulario)
    formulario.perguntas_de_resposta.to_h { |pergunta| [ pergunta.chave, valor_valido(formulario, pergunta) ] }
  end

  def valor_valido(formulario, pergunta)
    case pergunta.tipo
    when "texto" then "Resposta #{pergunta.numero}"[0, pergunta.maximo]
    when "numero" then 3.clamp(pergunta.minimo, pergunta.maximo).to_s
    when "data" then (pergunta.nao_antes_de ? Date.current : Date.current - 30).iso8601
    when "unica"
      # Escolhe a opção que revela a pergunta seguinte, para testar a condicional
      formulario.condicional_seguinte(pergunta)&.condicao&.fetch("valores")&.first || pergunta.opcoes.first.codigo
    when "multipla" then pergunta.opcoes.reject(&:exclusiva).first(2).map(&:codigo)
    end
  end

  def assert_campo_preenchido(pergunta, valor)
    nome = "avaliacao_clinica[dados_formulario][#{pergunta.chave}]"
    case pergunta.tipo
    when "unica" then assert_select "input[type=radio][name='#{nome}'][value='#{valor}'][checked]", 1, "pergunta #{pergunta.numero}"
    when "multipla"
      valor.each { |codigo| assert_select "input[type=checkbox][name='#{nome}[]'][value='#{codigo}'][checked]", 1, "pergunta #{pergunta.numero}" }
    when "texto"
      assert_select "[name='#{nome}']" do |campos|
        assert_equal valor, campos.first.name == "textarea" ? campos.first.text.strip : campos.first["value"], "pergunta #{pergunta.numero}"
      end
    else assert_select "input[name='#{nome}'][value='#{valor}']", 1, "pergunta #{pergunta.numero}"
    end
  end

  # IDs únicos e todo campo visível com rótulo associado
  def assert_html_acessivel
    pagina = Nokogiri::HTML5(response.body)
    ids = pagina.css("[id]").map { |elemento| elemento["id"] }
    assert_equal ids.uniq, ids, "IDs duplicados: #{ids.tally.select { |_, total| total > 1 }.keys}"

    pagina.css("input:not([type=hidden]):not([type=submit]), select, textarea").each do |campo|
      rotulado = campo["id"].present? && pagina.at_css("label[for='#{campo['id']}']") || campo.ancestors("label").any?
      assert rotulado, "campo sem rótulo: #{campo['name']}"
    end
  end
end
