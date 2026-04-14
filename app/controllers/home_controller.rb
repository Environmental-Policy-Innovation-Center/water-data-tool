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
      data: records.map { |pws| row_for(pws) }
    }
  end

  def filter_params
    params.permit(
      :gw_sw_code, :has_source_protection, :is_wholesaler, :is_school_or_daycare,
      :has_open_violations, :service_area_type, :area_min, :area_max,
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

  def row_for(pws) # rubocop:disable Metrics/MethodLength
    vs = pws.violations_summary
    dm = pws.demographic
    ej = pws.environmental_justice
    fs = pws.funding_summary
    wh = pws.watershed_hazard
    bws = pws.boil_water_summary

    {
      pws_name: pws.pws_name,
      pwsid: pws.pwsid,
      detailed_facility_report: pws.detailed_facility_report,
      stusps: pws.stusps,
      counties: pws.counties,
      gw_sw_code: pws.gw_sw_code,
      source_water_protection_code: pws.source_water_protection_code,
      owner_type: pws.owner_type,
      primacy_type: pws.primacy_type,
      is_wholesaler: pws.is_wholesaler,
      is_school_or_daycare: pws.is_school_or_daycare,
      symbology_field: pws.symbology_field,
      area_sq_miles: pws.area_sq_miles,
      open_health_viol: pws.open_health_viol,
      # Violations — 5yr
      health_violations_5yr: vs&.health_violations_5yr || 0,
      groundwater_rule_5yr: vs&.groundwater_rule_5yr || 0,
      surface_water_treatment_5yr: vs&.surface_water_treatment_5yr || 0,
      lead_and_copper_5yr: vs&.lead_and_copper_5yr || 0,
      radionuclides_5yr: vs&.radionuclides_5yr || 0,
      inorganic_chemicals_5yr: vs&.inorganic_chemicals_5yr || 0,
      synthetic_organic_chemicals_5yr: vs&.synthetic_organic_chemicals_5yr || 0,
      volatile_organic_chemicals_5yr: vs&.volatile_organic_chemicals_5yr || 0,
      total_coliform_5yr: vs&.total_coliform_5yr || 0,
      stage_1_disinfectants_5yr: vs&.stage_1_disinfectants_5yr || 0,
      stage_2_disinfectants_5yr: vs&.stage_2_disinfectants_5yr || 0,
      # Violations — 10yr
      health_violations_10yr: vs&.health_violations_10yr || 0,
      groundwater_rule_10yr: vs&.groundwater_rule_10yr || 0,
      surface_water_treatment_10yr: vs&.surface_water_treatment_10yr || 0,
      lead_and_copper_10yr: vs&.lead_and_copper_10yr || 0,
      radionuclides_10yr: vs&.radionuclides_10yr || 0,
      inorganic_chemicals_10yr: vs&.inorganic_chemicals_10yr || 0,
      synthetic_organic_chemicals_10yr: vs&.synthetic_organic_chemicals_10yr || 0,
      volatile_organic_chemicals_10yr: vs&.volatile_organic_chemicals_10yr || 0,
      total_coliform_10yr: vs&.total_coliform_10yr || 0,
      stage_1_disinfectants_10yr: vs&.stage_1_disinfectants_10yr || 0,
      stage_2_disinfectants_10yr: vs&.stage_2_disinfectants_10yr || 0,
      # Non-health violations
      paperwork_violations_5yr: vs&.paperwork_violations_5yr || 0,
      paperwork_violations_10yr: vs&.paperwork_violations_10yr || 0,
      # Boil water
      total_notices: bws&.total_notices || 0,
      # Demographics
      total_population: dm&.total_population || 0,
      population_density: dm&.population_density,
      poverty_rate: dm&.poverty_rate,
      unemployment_rate: dm&.unemployment_rate,
      median_household_income: dm&.median_household_income,
      bachelors_degree_rate: dm&.bachelors_degree_rate,
      age_under_5_rate: dm&.age_under_5_rate,
      age_over_61_rate: dm&.age_over_61_rate,
      poc_rate: dm&.poc_rate,
      white_rate: dm&.white_rate,
      black_rate: dm&.black_rate,
      aian_rate: dm&.aian_rate,
      napi_rate: dm&.napi_rate,
      asian_rate: dm&.asian_rate,
      hispanic_rate: dm&.hispanic_rate,
      other_race_rate: dm&.other_race_rate,
      mixed_race_rate: dm&.mixed_race_rate,
      most_common_rate_tier: dm&.most_common_rate_tier,
      # Environmental justice
      cejst_disadvantaged_pct: ej&.cejst_disadvantaged_pct,
      svi_overall_pctl: ej&.svi_overall_pctl,
      cvi_overall_score: ej&.cvi_overall_score,
      # Funding
      times_funded: fs&.times_funded || 0,
      total_srf_assistance: fs&.total_srf_assistance,
      total_principal_forgiveness: fs&.total_principal_forgiveness,
      # Watershed hazards
      num_facilities: wh&.num_facilities || 0,
      permit_effluent_violations: wh&.permit_effluent_violations || 0,
      open_underground_storage_tanks: wh&.open_underground_storage_tanks || 0,
      risk_management_plan_facilities: wh&.risk_management_plan_facilities || 0,
      impaired_streams_303d: wh&.impaired_streams_303d || 0
    }
  end
end
