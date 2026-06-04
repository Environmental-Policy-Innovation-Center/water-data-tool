require "csv"

class PublicWaterSystemExporter
  BATCH_SIZE = 500

  # Exported GeoJSON property columns, grouped by SQL table alias.
  # Each [alias, columns] pair expands to alias.col => alias.col entries.
  # The one renamed property (total_bwn → bws.total_notices) is merged at the end.
  GEOJSON_PROPERTY_COLUMNS = [
    ["pws", %w[
      pwsid pws_name detailed_facility_report stusps counties gw_sw_code
      source_water_protection_code owner_type primacy_type is_wholesaler
      is_school_or_daycare service_area_type area_sq_miles open_health_viol
    ]],
    ["vs", %w[
      health_violations_5yr groundwater_rule_5yr surface_water_treatment_5yr
      lead_and_copper_5yr radionuclides_5yr inorganic_chemicals_5yr
      synthetic_organic_chemicals_5yr volatile_organic_chemicals_5yr
      total_coliform_5yr stage_1_disinfectants_5yr stage_2_disinfectants_5yr
      health_violations_10yr groundwater_rule_10yr surface_water_treatment_10yr
      lead_and_copper_10yr radionuclides_10yr inorganic_chemicals_10yr
      synthetic_organic_chemicals_10yr volatile_organic_chemicals_10yr
      total_coliform_10yr stage_1_disinfectants_10yr stage_2_disinfectants_10yr
      paperwork_violations_5yr paperwork_violations_10yr
    ]],
    ["d", %w[
      total_population population_density poverty_rate unemployment_rate
      median_household_income bachelors_degree_rate age_under_5_rate age_over_61_rate
      poc_rate white_rate black_rate aian_rate napi_rate asian_rate hispanic_rate
      other_race_rate mixed_race_rate most_common_rate_tier
    ]],
    ["td", %w[population_pct_change mhi_pct_change]],
    ["ej", %w[cejst_disadvantaged_pct svi_overall_pctl cvi_overall_score]],
    ["fs", %w[times_funded total_srf_assistance total_principal_forgiveness]],
    ["wh", %w[
      num_facilities permit_effluent_violations open_underground_storage_tanks
      risk_management_plan_facilities impaired_streams_303d
    ]]
  ].each_with_object({}) { |(tbl, cols), h|
    cols.each { |col| h[col] = "#{tbl}.#{col}" }
  }.merge("total_bwn" => "bws.total_notices").freeze

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

  def initialize(scope)
    @scope = scope
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << CSV_HEADERS
      @scope.each { |pws| csv << csv_row(pws) }
    end
  end

  # Returns an Enumerator that streams a GeoJSON FeatureCollection as JSON
  # chunks. All serialisation (geometry encoding, property building) runs in
  # PostgreSQL via ST_AsGeoJSON + json_build_object; records are fetched in
  # cursor-based batches to keep memory usage flat regardless of result size.
  def to_geojson_stream
    Enumerator.new do |stream|
      stream << '{"type":"FeatureCollection","features":['
      first = true
      # Empty string is a valid sentinel: all EPA pwsids are non-empty, so
      # WHERE pws.pwsid > '' matches every row on the first iteration.
      last_pwsid = ""
      loop do
        rows = fetch_feature_batch(last_pwsid)
        break if rows.ntuples.zero?
        rows.each do |row|
          stream << "," unless first
          first = false
          stream << row["feature"]
          last_pwsid = row["pwsid"]
        end
        break if rows.ntuples < BATCH_SIZE
      end
      stream << "]}"
    end
  end

  private

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

  def properties_sql
    # PostgreSQL's json_build_object caps at 100 arguments (50 key-value pairs).
    # Slice at 49 pairs to stay safely under that limit; merge chunks via the
    # JSONB || operator then cast back to json.
    # All keys and column references come from frozen constants — never extend
    # this with runtime/user-supplied values.
    @properties_sql ||= begin
      conn = ApplicationRecord.connection
      chunks = GEOJSON_PROPERTY_COLUMNS.each_slice(49).map do |slice|
        pairs = slice.flat_map do |k, v|
          table, col = v.split(".")
          [conn.quote(k), "#{conn.quote_column_name(table)}.#{conn.quote_column_name(col)}"]
        end
        "jsonb_build_object(#{pairs.join(", ")})"
      end
      "(#{chunks.join(" || ")})::json"
    end
  end

  def filtered_ids_sql
    @filtered_ids_sql ||= @scope.unscope(:order).select("public_water_systems.pwsid").distinct.to_sql
  end

  # SAFETY: all interpolated SQL fragments (properties_sql, filtered_ids_sql,
  # BATCH_SIZE) are derived from frozen constants or sanitised inputs.
  # Never pass user-supplied data into this method.
  def fetch_feature_batch(last_pwsid)
    quoted = ApplicationRecord.connection.quote(last_pwsid)
    ApplicationRecord.connection.execute(<<~SQL)
      SELECT
        pws.pwsid,
        json_build_object(
          'type', 'Feature',
          'geometry', ST_AsGeoJSON(sag.geom)::json,
          'properties', #{properties_sql}
        )::text AS feature
      FROM public_water_systems pws
      INNER JOIN (#{filtered_ids_sql}) filtered ON filtered.pwsid = pws.pwsid
      LEFT JOIN service_area_geometries sag ON sag.pwsid = pws.pwsid
      LEFT JOIN violations_summaries   vs  ON vs.pwsid  = pws.pwsid
      LEFT JOIN boil_water_summaries   bws ON bws.pwsid = pws.pwsid
      LEFT JOIN demographics           d   ON d.pwsid   = pws.pwsid
      LEFT JOIN trend_data             td  ON td.pwsid  = pws.pwsid
      LEFT JOIN environmental_justices ej  ON ej.pwsid  = pws.pwsid
      LEFT JOIN funding_summaries      fs  ON fs.pwsid  = pws.pwsid
      LEFT JOIN watershed_hazards      wh  ON wh.pwsid  = pws.pwsid
      WHERE pws.pwsid > #{quoted}
      ORDER BY pws.pwsid
      LIMIT #{BATCH_SIZE}
    SQL
  end
end
