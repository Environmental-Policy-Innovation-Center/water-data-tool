class HomeController < ApplicationController
  PAGE_SIZE = 100

  ORDERABLE_COLUMNS = {
    0 => "public_water_systems.pws_name",
    1 => "public_water_systems.pwsid",
    3 => "public_water_systems.stusps",
    4 => "public_water_systems.counties",
    5 => "public_water_systems.gw_sw_code",
    6 => "public_water_systems.source_water_protection_code",
    7 => "public_water_systems.owner_type",
    8 => "public_water_systems.primacy_type",
    11 => "public_water_systems.symbology_field",
    12 => "public_water_systems.area_sq_miles",
    13 => "public_water_systems.open_health_viol"
  }.freeze

  def index
    @last_updated = DataImport.maximum(:imported_at)
  end

  def table
    respond_to do |format|
      format.json { render json: datatable_response }
    end
  end

  private

  def datatable_response
    draw = params[:draw].to_i
    start = params[:start].to_i
    length = params[:length].present? ? [params[:length].to_i, 1].max : PAGE_SIZE
    search = params.dig(:search, :value).to_s.strip

    total = PublicWaterSystem.count(:pwsid)

    scoped = PublicWaterSystem.apply_filters(filter_params)
    scoped = apply_search(scoped, search) if search.present?
    filtered = scoped.count(:pwsid)

    records = scoped
      .preload(:violations_summary, :demographic, :environmental_justice,
        :funding_summary, :watershed_hazard, :boil_water_summary)
      .order(order_clause)
      .offset(start)
      .limit(length)

    {
      draw: draw,
      recordsTotal: total,
      recordsFiltered: filtered,
      data: records.map { |pws| PublicWaterSystemTableSerializer.new(pws).serialize }
    }
  end

  def filter_params
    params.permit(
      :gw_sw_code, :has_source_protection, :is_wholesaler, :is_school_or_daycare,
      :has_open_violations, :symbology_field, :area_min, :area_max,
      :density_min, :density_max, :most_common_rate_tier, :state,
      :place_geoid, :county_geoid, :bounds,
      :health_violations_5yr_min, :health_violations_10yr_min,
      :paperwork_violations_5yr_min, :paperwork_violations_10yr_min,
      :boil_water_notices_min, :boil_water_notices_max,
      owner_type: [], primacy_type: [], pop_cat_5: []
    )
  end

  def apply_search(scope, term)
    sanitized = term.gsub(/[%_\\]/) { |c| "\\#{c}" }
    scope.where(
      "public_water_systems.pws_name ILIKE :q OR public_water_systems.pwsid ILIKE :q " \
      "OR public_water_systems.stusps ILIKE :q OR public_water_systems.counties ILIKE :q",
      q: "%#{sanitized}%"
    )
  end

  def order_clause
    col_idx = params.dig("order", "0", "column").to_i
    dir = (params.dig("order", "0", "dir") == "desc") ? "DESC" : "ASC"
    col = ORDERABLE_COLUMNS.fetch(col_idx, "public_water_systems.pws_name")
    Arel.sql("#{col} #{dir}")
  end
end
