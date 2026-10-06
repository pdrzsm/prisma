# Uso: validates :cpf, cpf: true
class CpfValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :invalid) unless Cpf.valido?(value)
  end
end
