# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# Plural em português dos models (o Rails pluraliza em inglês por padrão).
# Mantém tabela, rotas, associações e form_with com o mesmo nome.
# Plurais em português que o Rails não sabe fazer sozinho (ele faria
# "instituicaos" e "setors"): valem para tabelas, rotas e associações.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "avaliacao_clinica", "avaliacoes_clinicas"
  inflect.irregular "instituicao", "instituicoes"
  inflect.irregular "setor", "setores"
  inflect.irregular "formulario_habilitado", "formularios_habilitados"
end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end
