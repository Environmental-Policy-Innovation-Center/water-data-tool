# frozen_string_literal: true

module PublicWaterSystems
  class HistogramsController < ApplicationController
    FIELD_CONFIG = FieldRegistry.histogram_field_config.freeze

    def show
      field = params[:field]
      field_config = FIELD_CONFIG[field&.to_sym]
      return render json: {error: "Unknown field"}, status: :bad_request unless field_config

      model = field_config[:model]
      kwargs = field_config.except(:model)
      render json: model_scope(model, params[:state]).histogram_bins(field, **kwargs)
    end

    private

    def model_scope(model, stusps)
      return model unless stusps.present?
      model.where(pwsid: PublicWaterSystem.where(stusps: stusps).select(:pwsid))
    end
  end
end
