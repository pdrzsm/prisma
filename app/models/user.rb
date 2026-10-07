class User < ApplicationRecord
  # Atributo virtual para aceitar CPF ou username no login
  attr_writer :login

  # Sem :rememberable: o "lembrar de mim" desativa o timeout de sessão, o que é
  # ruim em computador compartilhado. Sem :registerable/:recoverable: contas e
  # senhas são geridas pela administração (Configurações > Usuários).
  devise :database_authenticatable, :lockable, :timeoutable

  # Auditoria sem o hash da senha; zerar o contador de tentativas não gera versão
  has_paper_trail skip: %i[encrypted_password], ignore: %i[failed_attempts]

  # Papel global, gravado como texto explícito:
  #   admin:   a conta única que administra o sistema e tem acesso a tudo;
  #   usuario: faz só o que o admin liberar, por instituição, setor e
  #            formulário (ver Permissoes).
  # Só existe um admin: o banco garante (índice único em admin_unico) e a
  # validação abaixo dá a mensagem. A tela nunca cria nem promove um admin.
  enum :role, { admin: "admin", usuario: "usuario" }, validate: true

  has_many :liberacoes_instituicao, class_name: "LiberacaoInstituicao", dependent: :destroy, inverse_of: :user
  has_many :liberacoes_setor, class_name: "LiberacaoSetor", dependent: :destroy, inverse_of: :user
  has_many :liberacoes_formulario, class_name: "LiberacaoFormulario", dependent: :destroy, inverse_of: :user

  # Determinístico para permitir o login por CPF (busca exata no banco)
  encrypts :cpf, deterministic: true

  normalizes :username, with: ->(username) { username.strip.downcase }
  normalizes :cpf, with: ->(cpf) { Cpf.normalizar(cpf) }
  normalizes :nome, with: ->(nome) { nome.squish }

  validates :nome, presence: true, length: { maximum: 150 }
  validates :username, presence: true, uniqueness: true,
                       format: { with: /\A[a-z0-9._-]+\z/, message: "apenas letras, números, ponto, traço e sublinhado" }
  validates :cpf, presence: true
  validates :cpf, cpf: true, uniqueness: true, allow_blank: true
  validates :password, presence: true, if: :new_record?
  validates :password, length: { within: Devise.password_length }, confirmation: true, allow_blank: true
  validate :admin_unico, if: :admin?
  validate :admin_sempre_ativo, if: :admin?

  # O que a pessoa pode fazer em cada setor e formulário (lido uma vez por objeto)
  def permissoes
    @permissoes ||= Permissoes.new(self)
  end

  def reload(*)
    @permissoes = nil
    super
  end

  # Conta desativada não entra; uma sessão já aberta cai na próxima requisição
  # (o Devise confere isto a cada requisição)
  def active_for_authentication?
    super && ativo?
  end

  def inactive_message
    ativo? ? super : :desativada
  end

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

  private

  def admin_unico
    errors.add(:role, "admin já existe: o sistema tem uma só conta admin") if User.admin.where.not(id:).exists?
  end

  def admin_sempre_ativo
    errors.add(:ativo, "a conta admin não pode ser desativada") unless ativo?
  end
end
