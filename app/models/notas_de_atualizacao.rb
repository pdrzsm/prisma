# As notas de atualização (config/notas_de_atualizacao.yml), da mais recente
# para a mais antiga, para o painel "Novidades" do topo.
class NotasDeAtualizacao
  Nota = Data.define(:data, :titulo, :itens)

  def self.todas
    @todas ||= YAML.safe_load_file(Rails.root.join("config/notas_de_atualizacao.yml"), permitted_classes: [ Date ])
                   .map { |nota| Nota.new(data: nota.fetch("data"), titulo: nota.fetch("titulo"), itens: nota.fetch("itens")) }
                   .sort_by(&:data).reverse
  end
end
