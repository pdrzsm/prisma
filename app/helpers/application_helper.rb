module ApplicationHelper
  BOTAO_PRIMARIO = "inline-flex items-center justify-center px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-medium text-sm rounded-lg shadow-sm transition"
  BOTAO_SECUNDARIO = "inline-flex items-center justify-center px-4 py-2 border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 font-medium text-sm rounded-lg transition"
  CAMPO = "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-200 aria-invalid:border-rose-400"

  # Aba da navegação principal; a ativa ganha destaque e aria-current
  def aba(titulo, caminho, ativa:)
    estado = ativa ? "border-indigo-600 text-indigo-700" : "border-transparent text-slate-500 hover:text-slate-800 hover:border-slate-300"
    link_to titulo, caminho, class: "py-3 border-b-2 text-sm font-semibold transition #{estado}", aria: { current: ativa ? "page" : nil }
  end

  def data_e_hora(momento)
    momento&.strftime("%d/%m/%Y %H:%M")
  end

  def selo_da_situacao(avaliacao)
    return unless avaliacao.definicao.campo_encerramento

    if avaliacao.encerrada?
      tag.span "Encerrada", class: "inline-flex whitespace-nowrap rounded-full bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-700"
    else
      tag.span "Em acompanhamento", class: "inline-flex whitespace-nowrap rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-semibold text-emerald-700"
    end
  end
end
