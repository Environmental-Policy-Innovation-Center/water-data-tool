module PublicWaterSystems
  class HistogramsController < ApplicationController
    ALLOWED_FIELDS = (
      Filterable::PAPERWORK_VIOLATIONS_COLS.map(&:to_s) +
      Filterable::HEALTH_SUBCATS_ALL.map(&:to_s)
    ).freeze

    def show
      field = params[:field]
      unless ALLOWED_FIELDS.include?(field)
        render json: {error: "Unknown field"}, status: :bad_request
        return
      end

      render json: ViolationsSummary.histogram_bins(field)
    end
  end
end
