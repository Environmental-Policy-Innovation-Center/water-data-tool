module PublicWaterSystems
  class ExportsController < ApplicationController
    include Sortable

    def create
      exporter = PublicWaterSystemExporter.new(build_export_scope)
      (params[:file_format] == "geojson") ? render_geojson_export(exporter) : render_csv_export(exporter)
    end

    private

    def build_export_scope
      apply_sort_join(filtered_scope).order(order_clause)
    end

    def filtered_scope
      ep = export_params
      return PublicWaterSystem.where(pwsid: ep[:pwsids]) if ep[:pwsids].present?

      scope = PublicWaterSystem.apply_filters(FilterParams.permit(params))
      scope = apply_search(scope, params[:search].to_s.strip) if params[:search].present?
      scope = scope.where.not(pwsid: ep[:exclude_pwsids]) if ep[:exclude_pwsids].present?
      scope
    end

    def export_params
      params.permit(pwsids: [], exclude_pwsids: [])
    end

    def render_csv_export(exporter)
      response.content_type = "text/csv"
      response.headers["Content-Disposition"] = 'attachment; filename="drinking_water_explorer_export.csv"'
      self.response_body = exporter.to_csv_stream
    end

    def render_geojson_export(exporter)
      response.content_type = "application/json; charset=utf-8"
      response.headers["Content-Disposition"] = 'attachment; filename="export.geojson"'
      self.response_body = exporter.to_geojson_stream
    end
  end
end
