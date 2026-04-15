class PublicWaterSystemsController < ApplicationController
  SORTABLE_COLUMNS = %w[
    pwsid pws_name stusps pop_cat_5 population_served_count
    service_connections_count gw_sw_code owner_type primacy_type
    service_area_type area_sq_miles open_health_viol
  ].freeze

  def index
    scope = PublicWaterSystem.apply_filters(params)
    scope = apply_sort(scope)
    @pagy, systems = pagy(:offset, scope)

    render json: {
      total_count: @pagy.count,
      page: @pagy.page,
      per_page: @pagy.limit,
      results: systems.map { |pws| PublicWaterSystemSerializer.new(pws).serialize },
      summary: build_summary(scope, @pagy.count)
    }
  end

  def show
    pws = PublicWaterSystem
      .with_details
      .find_by(pwsid: params[:pwsid])

    if pws
      render json: PublicWaterSystemDetailSerializer.new(pws).serialize
    else
      render json: {error: "Public water system not found"}, status: :not_found
    end
  end

  def export
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

  def apply_sort(scope)
    column = SORTABLE_COLUMNS.include?(params[:sort_by]) ? params[:sort_by] : "pwsid"
    direction = (params[:sort_dir]&.downcase == "desc") ? :desc : :asc
    scope.order(column => direction)
  end

  # Single query: SUM and COUNT(*) FILTER combined (PostgreSQL). systems_count
  # reuses @pagy.count. unscope(:order) required — ORDER BY is invalid on aggregates.
  def build_summary(scope, total_count)
    total_pop, open_viol_count = scope.unscope(:order).pick(
      Arel.sql("SUM(population_served_count)"),
      Arel.sql("COUNT(*) FILTER (WHERE open_health_viol = 'Yes')")
    )
    {
      systems_count: total_count,
      total_population_served: total_pop,
      systems_with_open_violations: open_viol_count
    }
  end

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
