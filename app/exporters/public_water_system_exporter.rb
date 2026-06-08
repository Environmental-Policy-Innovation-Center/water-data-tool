require "csv"

class PublicWaterSystemExporter
  # Matches Rails find_in_batches default. Batching is explicit — pluck and raw SQL
  # return all results in one shot without it.
  BATCH_SIZE = 1000

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

  # Single source of truth for CSV columns: header => sql_expression.
  # Boolean columns use ::text so PG emits "true"/"false" rather than "t"/"f".
  CSV_COLUMN_MAP = {
    "Utility Name" => "pws.pws_name",
    "Utility ID" => "pws.pwsid",
    "EPA Facility Report" => "pws.detailed_facility_report",
    "State" => "pws.stusps",
    "County" => "pws.counties",
    "Source type" => "pws.gw_sw_code",
    "Has source water protection" => "pws.source_water_protection_code::text",
    "Ownership" => "pws.owner_type",
    "Authority" => "pws.primacy_type",
    "Wholesaler" => "pws.is_wholesaler::text",
    "Facility type (School or daycare)" => "pws.is_school_or_daycare::text",
    "Grant eligible" => "pws.is_grant_eligible::text",
    "Boundary type" => "pws.service_area_type",
    "Size (Area in square miles)" => "pws.area_sq_miles",
    "Has open violations" => "pws.open_health_viol::text",
    "Health violations in the last 5 years" => "vs.health_violations_5yr",
    "Ground water rule violations in the last 5 years" => "vs.groundwater_rule_5yr",
    "Surface water treatment rules violations in the last 5 years" => "vs.surface_water_treatment_5yr",
    "Lead & copper violations in the last 5 years" => "vs.lead_and_copper_5yr",
    "Radionuclides violations in the last 5 years" => "vs.radionuclides_5yr",
    "Inorganic chemicals violations in the last 5 years" => "vs.inorganic_chemicals_5yr",
    "Synthetic organic chemicals violations in the last 5 years" => "vs.synthetic_organic_chemicals_5yr",
    "Volatile organic chemicals violations in the last 5 years" => "vs.volatile_organic_chemicals_5yr",
    "Coliform violations in the last 5 years" => "vs.total_coliform_5yr",
    "Stage 1 disinfectants violations in the last 5 years" => "vs.stage_1_disinfectants_5yr",
    "Stage 2 disinfectants violations in the last 5 years" => "vs.stage_2_disinfectants_5yr",
    "Health violations in the last 10 years" => "vs.health_violations_10yr",
    "Ground water rule violations in the last 10 years" => "vs.groundwater_rule_10yr",
    "Surface water treatment rules violations in the last 10 years" => "vs.surface_water_treatment_10yr",
    "Lead & copper violations in the last 10 years" => "vs.lead_and_copper_10yr",
    "Radionuclides violations in the last 10 years" => "vs.radionuclides_10yr",
    "Inorganic chemicals violations in the last 10 years" => "vs.inorganic_chemicals_10yr",
    "Synthetic organic chemicals violations in the last 10 years" => "vs.synthetic_organic_chemicals_10yr",
    "Volatile organic chemicals violations in the last 10 years" => "vs.volatile_organic_chemicals_10yr",
    "Coliform violations in the last 10 years" => "vs.total_coliform_10yr",
    "Stage 1 disinfectants violations in the last 10 years" => "vs.stage_1_disinfectants_10yr",
    "Stage 2 disinfectants violations in the last 10 years" => "vs.stage_2_disinfectants_10yr",
    "Non-health violations in the last 5 years" => "vs.paperwork_violations_5yr",
    "Non-health violations in the last 10 years" => "vs.paperwork_violations_10yr",
    "Boil water notices" => "bws.total_notices",
    "Population size" => "d.total_population",
    "Population density (people per square mile)" => "d.population_density",
    "Change in people in the last 10 years (%)" => "td.population_pct_change",
    "Change in income in the last 10 years (%)" => "td.mhi_pct_change",
    "Households below the poverty line (%)" => "d.poverty_rate",
    "Unemployment (%)" => "d.unemployment_rate",
    "Annual median household income ($)" => "d.median_household_income",
    "Higher education attainment (%)" => "d.bachelors_degree_rate",
    "Children under 5 (%)" => "d.age_under_5_rate",
    "Elderly over 61 (%)" => "d.age_over_61_rate",
    "People of color (%)" => "d.poc_rate",
    "White (%)" => "d.white_rate",
    "Black (%)" => "d.black_rate",
    "American Indian and Alaskan Native (%)" => "d.aian_rate",
    "Native Hawaiian and Pacific Islanders (%)" => "d.napi_rate",
    "Asian (%)" => "d.asian_rate",
    "Latino/a (%)" => "d.hispanic_rate",
    "Other (%)" => "d.other_race_rate",
    "Mixed race (%)" => "d.mixed_race_rate",
    "Disadvantaged area (%)" => "ej.cejst_disadvantaged_pct",
    "Social Vulnerability Index (%)" => "ej.svi_overall_pctl",
    "Climate Vulnerability Index (%)" => "ej.cvi_overall_score",
    "Annual water and sewer bill" => "d.most_common_rate_tier",
    "State revolving fund financing (2021 - 2025) - times received" => "fs.times_funded",
    "State revolving fund assistance (2021 - 2025) - amount received ($)" => "fs.total_srf_assistance",
    "State revolving fund principal forgiveness (2021 - 2025) - amount forgiven ($)" => "fs.total_principal_forgiveness",
    "Source water connections" => "wh.num_facilities",
    "Pollution permits with breaches" => "wh.permit_effluent_violations",
    "Underground storage tanks" => "wh.open_underground_storage_tanks",
    "Risk management plan facilities" => "wh.risk_management_plan_facilities",
    "Streams with impaired or threatened surface waters" => "wh.impaired_streams_303d"
  }.freeze

  def initialize(scope)
    @scope = scope
  end

  # Two-phase: pluck sorted pwsids first (preserves scope order), then batch-fetch raw SQL rows — no AR objects created.
  def to_csv_stream
    Enumerator.new do |stream|
      stream << CSV.generate_line(CSV_COLUMN_MAP.keys)
      sorted_ids = @scope.pluck(:pwsid)
      sorted_ids.each_slice(BATCH_SIZE) do |batch|
        rows_by_id = fetch_csv_batch(batch).index_by { |r| r["pwsid"] }
        batch.each do |id|
          row = rows_by_id[id]
          stream << CSV.generate_line(row.values) if row
        end
      end
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

  # LEFT JOIN clauses shared by both CSV and GeoJSON batch queries.
  # GeoJSON adds service_area_geometries on top; CSV does not need geometry.
  # SAFETY: all table/column references are from frozen constants — never
  # extend this with runtime or user-supplied values.
  ASSOCIATION_JOINS = <<~SQL.freeze
    LEFT JOIN violations_summaries   vs  ON vs.pwsid  = pws.pwsid
    LEFT JOIN boil_water_summaries   bws ON bws.pwsid = pws.pwsid
    LEFT JOIN demographics           d   ON d.pwsid   = pws.pwsid
    LEFT JOIN trend_data             td  ON td.pwsid  = pws.pwsid
    LEFT JOIN environmental_justices ej  ON ej.pwsid  = pws.pwsid
    LEFT JOIN funding_summaries      fs  ON fs.pwsid  = pws.pwsid
    LEFT JOIN watershed_hazards      wh  ON wh.pwsid  = pws.pwsid
  SQL

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

  # Fetches one page of GeoJSON features using cursor-based keyset pagination.
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
      #{ASSOCIATION_JOINS}
      WHERE pws.pwsid > #{quoted}
      ORDER BY pws.pwsid
      LIMIT #{BATCH_SIZE}
    SQL
  end

  # Fetches full CSV row data for an explicit ordered list of pwsids.
  # No AR objects are created; values are returned in CSV_COLUMN_MAP order.
  def fetch_csv_batch(pwsids)
    conn = ApplicationRecord.connection
    quoted_ids = pwsids.map { |id| conn.quote(id) }.join(", ")
    conn.execute(<<~SQL)
      SELECT #{CSV_COLUMN_MAP.values.join(", ")}
      FROM public_water_systems pws
      #{ASSOCIATION_JOINS}
      WHERE pws.pwsid IN (#{quoted_ids})
    SQL
  end
end
