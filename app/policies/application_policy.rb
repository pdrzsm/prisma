# Fechado por padrão: toda permissão é negada até uma policy filha liberar.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    # Segunda linha de defesa caso alguma rota pule o authenticate_user!
    raise Pundit::NotAuthorizedError, "é preciso estar autenticado" unless user

    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      raise Pundit::NotAuthorizedError, "é preciso estar autenticado" unless user

      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "Defina #resolve em #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
