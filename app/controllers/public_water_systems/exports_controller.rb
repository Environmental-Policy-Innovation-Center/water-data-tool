module PublicWaterSystems
  class ExportsController < ApplicationController
    include Sortable

    def create
      base_scope = if export_params[:pwsids].present?
        PublicWaterSystem.where(pwsid: export_params[:pwsids])
      else
        base = PublicWaterSystem.apply_filters(FilterParams.permit(params))
        base = apply_search(base, params[:search].to_s.strip) if params[:search].present?
        export_params[:exclude_pwsids].present? ? base.where.not(pwsid: export_params[:exclude_pwsids]) : base
      end

      base_scope = apply_sort_join(base_scope).order(order_clause)

      if params[:file_format] == "geojson"
        render_geojson_export(PublicWaterSystemExporter.new(base_scope))
      else
        render_csv_export(PublicWaterSystemExporter.new(base_scope.with_details))
      end
    end

    private

    def export_params
      params.permit(pwsids: [], exclude_pwsids: [])
    end

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
