class User < ApplicationRecord
  # Atributo virtual para aceitar CPF ou username no login
  attr_writer :login

  # Sem :rememberable: o "lembrar de mim" desativa o timeout de sessão, o que é
  # ruim em computador compartilhado. Sem :registerable/:recoverable: contas e
  # senhas são geridas pela administração.
  devise :database_authenticatable, :lockable, :timeoutable

  # Auditoria sem o hash da senha; zerar o contador de tentativas não gera versão
  has_paper_trail skip: %i[encrypted_password], ignore: %i[failed_attempts]

  # Valores explícitos no banco (não posicionais): reordenar ou incluir papéis
  # não muda o significado dos registros existentes. `validate: true` torna o
  # papel obrigatório e rejeita valores fora da lista com erro de validação.
  # operador: registra e visualiza | consultor: só visualiza | admin: tudo
  enum :role, { operador: "operador", consultor: "consultor", admin: "admin" }, validate: true

  # Determinístico para permitir o login por CPF (busca exata no banco)
  encrypts :cpf, deterministic: true

  normalizes :username, with: ->(username) { username.strip.downcase }
  normalizes :cpf, with: ->(cpf) { Cpf.normalizar(cpf) }

  validates :username, presence: true, uniqueness: true,
                       format: { with: /\A[a-z0-9._-]+\z/, message: "apenas letras, números, ponto, traço e sublinhado" }
  validates :cpf, presence: true
  validates :cpf, cpf: true, uniqueness: true, allow_blank: true
  validates :password, presence: true, if: :new_record?
  validates :password, length: { within: Devise.password_length }, confirmation: true, allow_blank: true

  # Leitor do atributo virtual: retorna o valor digitado ou o username/cpf
  def login
    @login || username || cpf
  end

  # Login por username ou por CPF, com ou sem pontuação
  def self.find_for_database_authentication(conditions)
    login = conditions[:login].to_s
    return if login.blank?

    find_by(username: login) || (Cpf.normalizar(login) && find_by(cpf: login))
  end
end
