class HomeController < ApplicationController
  SORTABLE_COLUMNS = %w[
    pws_name pwsid stusps counties gw_sw_code source_water_protection_code
    owner_type primacy_type is_wholesaler is_school_or_daycare symbology_field
    area_sq_miles open_health_viol
  ].freeze

  def index
    @last_updated = DataImport.maximum(:imported_at)
  end

  def map
    scope = PublicWaterSystem.apply_filters(filter_params)
    render json: {pwsids: scope.pluck(:pwsid)}
  end

  def table
    scope = PublicWaterSystem.apply_filters(filter_params)
    scope = apply_search(scope, params[:search].to_s.strip) if params[:search].present?
    preloads = [:violations_summary, :demographic, :environmental_justice,
      :funding_summary, :watershed_hazard, :boil_water_summary]
    @pagy, @systems = pagy(scope.preload(preloads).order(order_clause))
    render partial: "home/table"
  end

  private

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
    col = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : "pws_name"
    dir = (params[:direction] == "desc") ? "DESC" : "ASC"
    tiebreaker = (col == "pws_name") ? "" : ", public_water_systems.pws_name ASC"
    Arel.sql("public_water_systems.#{col} #{dir} NULLS LAST#{tiebreaker}")
  end
end
