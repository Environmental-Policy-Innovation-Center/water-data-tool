module PublicWaterSystems
  class HistogramsController < ApplicationController
    ALLOWED_FIELDS = %w[
      paperwork_violations_5yr paperwork_violations_10yr
    ].freeze

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
