require "csv"

class PublicWaterSystemsController < ApplicationController
  SORTABLE_COLUMNS = %w[
    pwsid pws_name stusps pop_cat_5 population_served_count
    service_connections_count gw_sw_code owner_type primacy_type
    service_area_type area_sq_miles open_health_viol
  ].freeze

  DETAIL_INCLUDES = %i[
    demographic violations_summary environmental_justice
    funding_summary watershed_hazard boil_water_summary
    trend_datum service_area_geometry
  ].freeze

  # Human-readable headers matching the legacy datatable_export.csv output.
  # Order matters — must stay in sync with #csv_row below.
  CSV_HEADERS = [
    "Utility Name", "Utility ID", "EPA Facility Report", "State", "County",
    "Source type", "Source protection", "Ownership", "Authority",
    "Wholesaler", "Facility type (School or daycare)", "Boundary type",
    "Size (Area in square miles)", "Open violations",
    "Health violations in the last 5 years",
    "Ground water rule violations in the last 5 years",
    "Surface water treatment rules violations in the last 5 years",
    "Lead & copper violations in the last 5 years",
    "Radionuclides violations in the last 5 years",
    "Inorganic chemicals violations in the last 5 years",
    "Synthetic organic chemicals violations in the last 5 years",
    "Volatile organic chemicals violations in the last 5 years",
    "Coliform violations in the last 5 years",
    "Stage 1 disinfectants violations in the last 5 years",
    "Stage 2 disinfectants violations in the last 5 years",
    "Health violations in the last 10 years",
    "Ground water rule violations in the last 10 years",
    "Surface water treatment rules violations in the last 10 years",
    "Lead & copper violations in the last 10 years",
    "Radionuclides violations in the last 10 years",
    "Inorganic chemicals violations in the last 10 years",
    "Synthetic organic chemicals violations in the last 10 years",
    "Volatile organic chemicals violations in the last 10 years",
    "Coliform violations in the last 10 years",
    "Stage 1 disinfectants violations in the last 10 years",
    "Stage 2 disinfectants violations in the last 10 years",
    "Non-health violations in the last 5 years",
    "Non-health violations in the last 10 years",
    "Boil water notices",
    "Population size", "Population density (people per square mile)",
    "Change in people in the last 10 years (%)",
    "Change in income in the last 10 years (%)",
    "Households below the poverty line (%)", "Unemployment (%)",
    "Annual median household income ($)", "Higher education attainment (%)",
    "Children under 5 (%)", "Elderly over 61 (%)", "People of color (%)",
    "White (%)", "Black (%)", "American Indian and Alaskan Native (%)",
    "Native Hawaiian and Pacific Islanders (%)", "Asian (%)", "Latino/a (%)",
    "Other (%)", "Mixed race (%)",
    "Disadvantaged area (%)", "Social Vulnerability Index (%)",
    "Climate Vulnerability Index (%)", "Annual water and sewer bill",
    "State revolving fund financing (2021 - 2025) - times received",
    "State revolving fund assistance (2021 - 2025) - amount received ($)",
    "State revolving fund principal forgiveness (2021 - 2025) - amount forgiven ($)",
    "Source water connections", "Pollution permits with breaches",
    "Underground storage tanks", "Risk management plan facilities",
    "Streams with impaired or threatened surface waters"
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
      summary: build_summary(scope)
    }
  end

  def show
    pws = PublicWaterSystem
      .includes(*DETAIL_INCLUDES)
      .find_by(pwsid: params[:pwsid])

    if pws
      render json: PublicWaterSystemDetailSerializer.new(pws).serialize
    else
      render json: {error: "Public water system not found", status: 404}, status: :not_found
    end
  end

  def export
    scope = PublicWaterSystem
      .apply_filters(params)
      .includes(*DETAIL_INCLUDES)

    if params[:file_format] == "geojson"
      render_geojson_export(scope)
    else
      render_csv_export(scope)
    end
  end

  private

  def apply_sort(scope)
    column = SORTABLE_COLUMNS.include?(params[:sort_by]) ? params[:sort_by] : "pwsid"
    direction = (params[:sort_dir]&.downcase == "desc") ? :desc : :asc
    scope.order(column => direction)
  end

  def build_summary(scope)
    {
      systems_count: scope.count,
      total_population_served: scope.sum(:population_served_count),
      systems_with_open_violations: scope.where(open_health_viol: "Yes").count
    }
  end

  def render_csv_export(scope)
    csv_data = CSV.generate(headers: true) do |csv|
      csv << CSV_HEADERS
      scope.each { |pws| csv << csv_row(pws) }
    end

    send_data csv_data,
      type: "text/csv",
      disposition: 'attachment; filename="drinking_water_explorer_export.csv"'
  end

  def render_geojson_export(scope)
    features = scope.map do |pws|
      geometry = if (geom = pws.service_area_geometry&.geom)
        RGeo::GeoJSON.encode(geom)
      end

      {type: "Feature", geometry: geometry, properties: geojson_properties(pws)}
    end

    compressed = ActiveSupport::Gzip.compress({type: "FeatureCollection", features: features}.to_json)

    response.headers["Content-Encoding"] = "gzip"
    send_data compressed,
      type: "application/json",
      disposition: 'attachment; filename="export.geojson"'
  end

  # IMPORTANT: order and count must stay in sync with CSV_HEADERS above.
  def csv_row(pws)
    vs = pws.violations_summary
    bws = pws.boil_water_summary
    d = pws.demographic
    td = pws.trend_datum
    ej = pws.environmental_justice
    fs = pws.funding_summary
    wh = pws.watershed_hazard

    [
      pws.pws_name, pws.pwsid, pws.detailed_facility_report,
      pws.stusps, pws.counties, pws.gw_sw_code, pws.source_water_protection_code,
      pws.owner_type, pws.primacy_type, pws.is_wholesaler, pws.is_school_or_daycare,
      pws.service_area_type, pws.area_sq_miles, pws.open_health_viol,
      vs&.health_violations_5yr, vs&.groundwater_rule_5yr, vs&.surface_water_treatment_5yr,
      vs&.lead_and_copper_5yr, vs&.radionuclides_5yr, vs&.inorganic_chemicals_5yr,
      vs&.synthetic_organic_chemicals_5yr, vs&.volatile_organic_chemicals_5yr,
      vs&.total_coliform_5yr, vs&.stage_1_disinfectants_5yr, vs&.stage_2_disinfectants_5yr,
      vs&.health_violations_10yr, vs&.groundwater_rule_10yr, vs&.surface_water_treatment_10yr,
      vs&.lead_and_copper_10yr, vs&.radionuclides_10yr, vs&.inorganic_chemicals_10yr,
      vs&.synthetic_organic_chemicals_10yr, vs&.volatile_organic_chemicals_10yr,
      vs&.total_coliform_10yr, vs&.stage_1_disinfectants_10yr, vs&.stage_2_disinfectants_10yr,
      vs&.paperwork_violations_5yr, vs&.paperwork_violations_10yr,
      bws&.total_notices,
      d&.total_population, d&.population_density,
      td&.population_pct_change, td&.mhi_pct_change,
      d&.poverty_rate, d&.unemployment_rate, d&.median_household_income,
      d&.bachelors_degree_rate, d&.age_under_5_rate, d&.age_over_61_rate,
      d&.poc_rate, d&.white_rate, d&.black_rate, d&.aian_rate, d&.napi_rate,
      d&.asian_rate, d&.hispanic_rate, d&.other_race_rate, d&.mixed_race_rate,
      ej&.cejst_disadvantaged_pct, ej&.svi_overall_pctl, ej&.cvi_overall_score,
      d&.most_common_rate_tier,
      fs&.times_funded, fs&.total_srf_assistance, fs&.total_principal_forgiveness,
      wh&.num_facilities, wh&.permit_effluent_violations,
      wh&.open_underground_storage_tanks, wh&.risk_management_plan_facilities,
      wh&.impaired_streams_303d
    ]
  end

  # Returns a flat hash of properties for GeoJSON features (snake_case keys,
  # matching the legacy download_geojson.php output).
  def geojson_properties(pws)
    vs = pws.violations_summary
    bws = pws.boil_water_summary
    d = pws.demographic
    td = pws.trend_datum
    ej = pws.environmental_justice
    fs = pws.funding_summary
    wh = pws.watershed_hazard

    {
      pws_name: pws.pws_name, pwsid: pws.pwsid,
      detailed_facility_report: pws.detailed_facility_report,
      stusps: pws.stusps, counties: pws.counties,
      gw_sw_code: pws.gw_sw_code, source_water_protection_code: pws.source_water_protection_code,
      owner_type: pws.owner_type, primacy_type: pws.primacy_type,
      is_wholesaler: pws.is_wholesaler, is_school_or_daycare: pws.is_school_or_daycare,
      service_area_type: pws.service_area_type, area_sq_miles: pws.area_sq_miles,
      open_health_viol: pws.open_health_viol,
      health_violations_5yr: vs&.health_violations_5yr,
      groundwater_rule_5yr: vs&.groundwater_rule_5yr,
      surface_water_treatment_5yr: vs&.surface_water_treatment_5yr,
      lead_and_copper_5yr: vs&.lead_and_copper_5yr,
      radionuclides_5yr: vs&.radionuclides_5yr,
      inorganic_chemicals_5yr: vs&.inorganic_chemicals_5yr,
      synthetic_organic_chemicals_5yr: vs&.synthetic_organic_chemicals_5yr,
      volatile_organic_chemicals_5yr: vs&.volatile_organic_chemicals_5yr,
      total_coliform_5yr: vs&.total_coliform_5yr,
      stage_1_disinfectants_5yr: vs&.stage_1_disinfectants_5yr,
      stage_2_disinfectants_5yr: vs&.stage_2_disinfectants_5yr,
      health_violations_10yr: vs&.health_violations_10yr,
      groundwater_rule_10yr: vs&.groundwater_rule_10yr,
      surface_water_treatment_10yr: vs&.surface_water_treatment_10yr,
      lead_and_copper_10yr: vs&.lead_and_copper_10yr,
      radionuclides_10yr: vs&.radionuclides_10yr,
      inorganic_chemicals_10yr: vs&.inorganic_chemicals_10yr,
      synthetic_organic_chemicals_10yr: vs&.synthetic_organic_chemicals_10yr,
      volatile_organic_chemicals_10yr: vs&.volatile_organic_chemicals_10yr,
      total_coliform_10yr: vs&.total_coliform_10yr,
      stage_1_disinfectants_10yr: vs&.stage_1_disinfectants_10yr,
      stage_2_disinfectants_10yr: vs&.stage_2_disinfectants_10yr,
      paperwork_violations_5yr: vs&.paperwork_violations_5yr,
      paperwork_violations_10yr: vs&.paperwork_violations_10yr,
      total_bwn: bws&.total_notices,
      total_population: d&.total_population,
      population_density: d&.population_density,
      population_pct_change: td&.population_pct_change,
      mhi_pct_change: td&.mhi_pct_change,
      poverty_rate: d&.poverty_rate,
      unemployment_rate: d&.unemployment_rate,
      median_household_income: d&.median_household_income,
      bachelors_degree_rate: d&.bachelors_degree_rate,
      age_under_5_rate: d&.age_under_5_rate,
      age_over_61_rate: d&.age_over_61_rate,
      poc_rate: d&.poc_rate,
      white_rate: d&.white_rate,
      black_rate: d&.black_rate,
      aian_rate: d&.aian_rate,
      napi_rate: d&.napi_rate,
      asian_rate: d&.asian_rate,
      hispanic_rate: d&.hispanic_rate,
      other_race_rate: d&.other_race_rate,
      mixed_race_rate: d&.mixed_race_rate,
      cejst_disadvantaged_pct: ej&.cejst_disadvantaged_pct,
      svi_overall_pctl: ej&.svi_overall_pctl,
      cvi_overall_score: ej&.cvi_overall_score,
      most_common_rate_tier: d&.most_common_rate_tier,
      times_funded: fs&.times_funded,
      total_srf_assistance: fs&.total_srf_assistance,
      total_principal_forgiveness: fs&.total_principal_forgiveness,
      num_facilities: wh&.num_facilities,
      permit_effluent_violations: wh&.permit_effluent_violations,
      open_underground_storage_tanks: wh&.open_underground_storage_tanks,
      risk_management_plan_facilities: wh&.risk_management_plan_facilities,
      impaired_streams_303d: wh&.impaired_streams_303d
    }
  end
end
