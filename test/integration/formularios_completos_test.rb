require "test_helper"

# Preenche todas as perguntas de cada formulário de teste
# (test/formularios_de_teste.rb), com respostas geradas a partir da própria
# definição: publica, habilita no setor, libera, registra, mostra e edita.
# Vale também para os formulários de teste que ainda vão existir.
class FormulariosCompletosTest < ActionDispatch::IntegrationTest
  ESTRUTURAS = FormulariosDeTeste::TODOS

  setup { sign_in users(:operador) }

  ESTRUTURAS.each do |chave, estrutura|
    test "#{chave}: registra, mostra e edita todas as perguntas" do
      formulario = preparar(chave, estrutura)
      definicao = formulario.definicao
      respostas = respostas_completas(definicao)
      esperado = definicao.normalizar(respostas)

      assert_difference "AvaliacaoClinica.count", 1 do
        post formulario_avaliacoes_clinicas_path(formulario), params: {
          paciente: { prontuario_sah: "SAH-COMPLETO", prontuario_aghuse: "AGH-COMPLETO", iniciais: "ABC" },
          avaliacao_clinica: { versao_formulario_id: formulario.versao_publicada_id, setor_id: setores(:ambulatorio).id,
                               dados_formulario: respostas }
        }
      end
      avaliacao = AvaliacaoClinica.order(:id).last
      assert_redirected_to formulario_avaliacao_clinica_path(formulario, avaliacao)
      assert_equal definicao.chaves.sort, esperado.keys.sort, "toda pergunta respondida (as condições à mostra)"
      assert_equal esperado, avaliacao.reload.respostas
      assert_equal formulario.versao_publicada, avaliacao.versao_formulario

      get formulario_avaliacao_clinica_path(formulario, avaliacao)
      definicao.perguntas.each do |pergunta|
        texto = ERB::Util.html_escape(definicao.resposta_formatada(pergunta, esperado[pergunta.chave]))
        assert_includes response.body, texto, "resposta da pergunta #{pergunta.numero} na visualização"
      end

      get edit_formulario_avaliacao_clinica_path(formulario, avaliacao)
      definicao.perguntas.each { |pergunta| assert_campo_preenchido(pergunta, esperado[pergunta.chave]) }
      assert_html_acessivel

      # Reenviar a edição sem mudar nada não cria versão nem conflito
      assert_no_difference -> { avaliacao.versions.count } do
        patch formulario_avaliacao_clinica_path(formulario, avaliacao), params: {
          avaliacao_clinica: { lock_version: avaliacao.reload.lock_version, dados_formulario: respostas }
        }
      end
      assert_redirected_to formulario_avaliacao_clinica_path(formulario, avaliacao)

      get formulario_avaliacoes_clinicas_path(formulario)
      definicao.perguntas_da_lista.each do |pergunta|
        assert_includes response.body, ERB::Util.html_escape(definicao.resposta_formatada(pergunta, esperado[pergunta.chave])), "coluna #{pergunta.chave}"
      end
    end

    test "#{chave}: tela de registro tem um campo com rótulo para cada pergunta" do
      formulario = preparar(chave, estrutura)
      get new_formulario_avaliacao_clinica_path(formulario)

      assert_response :success
      assert_select ".pergunta", formulario.definicao.perguntas.size + Paciente::IDENTIFICACAO.size
      assert_select "input[type=hidden][name='avaliacao_clinica[versao_formulario_id]'][value='#{formulario.versao_publicada_id}']"
      assert_html_acessivel
    end
  end

  private

  # Publicado, habilitado no Ambulatório e liberado para o operador registrar
  def preparar(chave, estrutura)
    return formularios(:acompanhamento) if chave == "acompanhamento"

    formulario = publicar_formulario(chave, estrutura)
    setores(:ambulatorio).formularios_habilitados.create!(formulario: chave)
    users(:operador).liberacoes_formulario.create!(setor: setores(:ambulatorio), formulario: chave, papel: "registra")
    formulario
  end

  def respostas_completas(definicao)
    definicao.perguntas.to_h { |pergunta| [ pergunta.chave, valor_valido(definicao, pergunta) ] }
  end

  # Uma resposta válida para cada tipo. Nas perguntas de escolha, as opções
  # que mostram as dependentes, para que todas sejam respondidas
  def valor_valido(definicao, pergunta)
    case pergunta.tipo
    when "texto" then "Resposta #{pergunta.numero}"[0, pergunta.maximo]
    when "texto_longo" then "Primeira linha #{pergunta.numero}\nSegunda linha"[0, pergunta.maximo]
    when "numero"
      valor = 3.clamp(pergunta.minimo, pergunta.maximo)
      pergunta.decimais.zero? || valor == pergunta.maximo ? valor.to_s : "#{valor},5"
    when "data" then (pergunta.nao_antes_de ? Date.current : Date.current - 30).iso8601
    when "unica", "lista_suspensa"
      pergunta.opcoes.max_by { |opcao| definicao.revelados_por(pergunta, opcao.codigo).size }.codigo
    when "multipla"
      comuns = pergunta.opcoes.reject(&:exclusiva)
      reveladoras = comuns.select { |opcao| definicao.revelados_por(pergunta, opcao.codigo).any? }
      (reveladoras + comuns).uniq.first([ reveladoras.size, 2 ].max).map(&:codigo)
    end
  end

  def assert_campo_preenchido(pergunta, valor)
    nome = "avaliacao_clinica[dados_formulario][#{pergunta.chave}]"
    case pergunta.tipo
    when "unica" then assert_select "input[type=radio][name='#{nome}'][value='#{valor}'][checked]", 1, "pergunta #{pergunta.numero}"
    when "lista_suspensa" then assert_select "select[name='#{nome}'] option[value='#{valor}'][selected]", 1, "pergunta #{pergunta.numero}"
    when "multipla"
      valor.each { |codigo| assert_select "input[type=checkbox][name='#{nome}[]'][value='#{codigo}'][checked]", 1, "pergunta #{pergunta.numero}" }
    when "texto", "texto_longo"
      assert_select "[name='#{nome}']" do |campos|
        assert_equal valor, campos.first.name == "textarea" ? campos.first.text.strip : campos.first["value"], "pergunta #{pergunta.numero}"
      end
    else assert_select "input[name='#{nome}'][value='#{valor}']", 1, "pergunta #{pergunta.numero}"
    end
  end

  # IDs únicos, todo campo visível com rótulo associado e toda descrição
  # (aria-describedby) apontando para um elemento que existe
  def assert_html_acessivel
    pagina = Nokogiri::HTML5(response.body)
    ids = pagina.css("[id]").map { |elemento| elemento["id"] }
    assert_equal ids.uniq, ids, "IDs duplicados: #{ids.tally.select { |_, total| total > 1 }.keys}"

    pagina.css("input:not([type=hidden]):not([type=submit]), select, textarea").each do |campo|
      rotulado = campo["id"].present? && pagina.at_css("label[for='#{campo['id']}']") || campo.ancestors("label").any?
      assert rotulado, "campo sem rótulo: #{campo['name']}"
    end
    pagina.css("[aria-describedby]").each do |elemento|
      elemento["aria-describedby"].split.each { |id| assert pagina.at_css("##{id}"), "aria-describedby sem destino: #{id}" }
    end
  end
end
