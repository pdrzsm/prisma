# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :cpf, :login, :sus_card, :medical_notes, :form_data,
  # Dados pessoais e de saúde (LGPD art. 11). :paciente e :avaliacao_clinica
  # mascaram o objeto inteiro (todos os formulários de config/formularios usam
  # essas duas chaves); os demais cobrem os mesmos campos fora desse aninhamento.
  :paciente, :avaliacao_clinica, :dados_formulario, :prontuario, :iniciais, :nome, :municipio_residencia
]
