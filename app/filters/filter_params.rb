# frozen_string_literal: true

class FilterParams
  def self.permit(params)
    params.permit(*FilterRegistry.permit_arguments)
  end
end
