# Gerador de formulários (Configurações > Gerador de formulários): só o admin
# cria, edita, publica e vê os rascunhos (ver ConfiguracaoPolicy). Usada com o
# namespace: authorize [:configuracoes, formulario]. Um formulário com
# notificações nunca é excluído (registro clínico); sem nenhuma, nada foi
# coletado com ele e ele sai inteiro, publicado ou não (Formulario#excluivel?).
module Configuracoes
  class FormularioPolicy < ConfiguracaoPolicy
    def show? = admin?
    def publicar? = admin?

    def destroy?
      admin? && record.is_a?(Formulario) && record.excluivel?
    end
  end
end
