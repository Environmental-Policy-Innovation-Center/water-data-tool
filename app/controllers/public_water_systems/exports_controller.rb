module PublicWaterSystems
  class ExportsController < ApplicationController
    def show
      scope = PublicWaterSystem
        .apply_filters(params)
        .with_details

      exporter = PublicWaterSystemExporter.new(scope)

      if params[:file_format] == "geojson"
        render_geojson_export(exporter)
      else
        render_csv_export(exporter)
      end
    end

    private

    def render_csv_export(exporter)
      send_data exporter.to_csv,
        type: "text/csv",
        disposition: 'attachment; filename="drinking_water_explorer_export.csv"'
    end

    def render_geojson_export(exporter)
      compressed = ActiveSupport::Gzip.compress(exporter.to_geojson.to_json)

      # Content-Encoding: gzip tells the browser to decompress before saving.
      # Rack::Deflater is NOT in the middleware stack, so there is no double-compression risk.
      response.headers["Content-Encoding"] = "gzip"
      send_data compressed,
        type: "application/json",
        disposition: 'attachment; filename="export.geojson"'
    end
  end
end
