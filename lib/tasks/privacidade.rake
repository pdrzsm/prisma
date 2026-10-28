namespace :prisma do
  desc "Apaga as leituras da auditoria mais antigas que DIAS dias (política de retenção definida com o encarregado). Sem CONFIRMAR=sim, só conta."
  task descartar_leituras: :environment do
    dias = Integer(ENV.fetch("DIAS") { abort "Informe DIAS=<número de dias a manter>, definido com o encarregado (DPO)." }, exception: false)
    abort "DIAS precisa ser um número inteiro maior que zero." unless dias&.positive?

    limite = dias.days.ago
    antigas = AuditLog.where(created_at: ...limite)

    if ENV["CONFIRMAR"] == "sim"
      # delete_all: o model é imutável (ReadOnlyRecord), e o descarte é uma decisão
      # da política de retenção. O usuário do banco que roda isto precisa de DELETE
      # em audit_logs, que o usuário da aplicação não tem (docs/seguranca.md).
      puts "#{antigas.delete_all} leituras anteriores a #{limite.to_date} apagadas."
    else
      puts "#{antigas.count} leituras anteriores a #{limite.to_date} seriam apagadas. Nada foi apagado; rode de novo com CONFIRMAR=sim."
    end
  end
end
