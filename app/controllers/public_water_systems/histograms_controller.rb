# frozen_string_literal: true

module PublicWaterSystems
  class HistogramsController < ApplicationController
    FIELD_CONFIG = FilterRegistry.histogram_field_config.freeze

    def show
      field = params[:field]
      field_config = FIELD_CONFIG[field&.to_sym]
      return render json: {error: "Unknown field"}, status: :bad_request unless field_config

      model = field_config[:model]
      kwargs = field_config.except(:model)
      render json: model.histogram_bins(field, **kwargs)
    end
  end
end
