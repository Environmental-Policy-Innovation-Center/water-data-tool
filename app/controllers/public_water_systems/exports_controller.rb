module PublicWaterSystems
  class ExportsController < ApplicationController
    def show
      base_scope = if params[:pwsids].present?
        PublicWaterSystem.where(pwsid: params[:pwsids])
      else
        PublicWaterSystem.apply_filters(FilterParams.permit(params))
      end

      if params[:file_format] == "geojson"
        render_geojson_export(PublicWaterSystemExporter.new(base_scope))
      else
        render_csv_export(PublicWaterSystemExporter.new(base_scope.with_details))
      end
    end

    private

    def render_csv_export(exporter)
      send_data exporter.to_csv,
        type: "text/csv",
        disposition: 'attachment; filename="drinking_water_explorer_export.csv"'
    end

    def render_geojson_export(exporter)
      response.content_type = "application/json; charset=utf-8"
      response.headers["Content-Disposition"] = 'attachment; filename="export.geojson"'
      # Content-Length is intentionally absent — the streamed response size is unknown in advance.
      self.response_body = exporter.to_geojson_stream
    end
  end
end
