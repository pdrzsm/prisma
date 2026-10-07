# Configurações > Usuários: só o admin (ver ConfiguracaoPolicy). Usuário nunca é
# excluído: é desativado, e a auditoria guarda o que ele fez. Liberações e
# senha temporária são só para usuários comuns: o admin tem acesso a tudo e
# troca a própria senha pela tela de senha, como todo mundo.
class UserPolicy < ConfiguracaoPolicy
  def destroy?
    false
  end

  def liberar?
    admin? && record.usuario?
  end

  def redefinir_senha?
    liberar?
  end
end
