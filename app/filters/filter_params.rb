# frozen_string_literal: true

class FilterParams
  def self.permit(params)
    params.permit(*FieldRegistry.permit_arguments)
  end
end
