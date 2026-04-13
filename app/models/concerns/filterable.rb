module Filterable
  extend ActiveSupport::Concern

  class_methods do
    def apply_filters(params)
      scope = all
      # Tracks which associations have been left-joined to prevent duplicates.
      joined = Set.new

      # --- Direct categorical filters (on public_water_systems) ---
      scope = scope.where(gw_sw_code: params[:gw_sw_code]) if params[:gw_sw_code].present?
      scope = scope.where(owner_type: params[:owner_type]) if params[:owner_type].present?
      scope = scope.where(primacy_type: params[:primacy_type]) if params[:primacy_type].present?
      scope = scope.where(pop_cat_5: params[:pop_cat_5]) if params[:pop_cat_5].present?
      scope = scope.where(service_area_type: params[:service_area_type]) if params[:service_area_type].present?

      # --- Boolean filters ---
      scope = scope.where(is_wholesaler: true) if params[:is_wholesaler] == "true"
      scope = scope.where(is_school_or_daycare: true) if params[:is_school_or_daycare] == "true"
      scope = scope.where(source_water_protection_code: "Yes") if params[:has_source_protection] == "true"
      scope = scope.where(open_health_viol: "Yes") if params[:has_open_violations] == "true"

      # --- Direct range filters (coerce to Decimal to guard against non-numeric input) ---
      scope = scope.where("area_sq_miles >= ?", params[:area_min].to_d) if params[:area_min].present?
      scope = scope.where("area_sq_miles <= ?", params[:area_max].to_d) if params[:area_max].present?

      # --- State filter ---
      scope = scope.where(stusps: params[:state]) if params[:state].present?

      # --- Violations range filters (join to violations_summaries) ---
      violations_range_filters = %i[
        health_violations_5yr
        groundwater_rule_5yr surface_water_treatment_5yr lead_and_copper_5yr
        radionuclides_5yr inorganic_chemicals_5yr synthetic_organic_chemicals_5yr
        volatile_organic_chemicals_5yr total_coliform_5yr
        stage_1_disinfectants_5yr stage_2_disinfectants_5yr paperwork_violations_5yr
        health_violations_10yr
        groundwater_rule_10yr surface_water_treatment_10yr lead_and_copper_10yr
        radionuclides_10yr inorganic_chemicals_10yr synthetic_organic_chemicals_10yr
        volatile_organic_chemicals_10yr total_coliform_10yr
        stage_1_disinfectants_10yr stage_2_disinfectants_10yr paperwork_violations_10yr
      ]

      if violations_range_filters.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
        scope, joined = left_join_once(scope, joined, :violations_summary)
      end

      violations_range_filters.each do |col|
        if params[:"#{col}_min"].present?
          scope = scope.where("violations_summaries.#{col} >= ?", params[:"#{col}_min"].to_i)
        end
        if params[:"#{col}_max"].present?
          scope = scope.where("violations_summaries.#{col} <= ?", params[:"#{col}_max"].to_i)
        end
      end

      # --- Boil water notice range filter ---
      if params[:boil_water_notices_min].present? || params[:boil_water_notices_max].present?
        scope, joined = left_join_once(scope, joined, :boil_water_summary)
        scope = scope.where("boil_water_summaries.total_notices >= ?", params[:boil_water_notices_min].to_i) if params[:boil_water_notices_min].present?
        scope = scope.where("boil_water_summaries.total_notices <= ?", params[:boil_water_notices_max].to_i) if params[:boil_water_notices_max].present?
      end

      # --- Demographic range filters ---
      demographic_range_filters = %i[
        total_population poverty_rate population_in_poverty_rate unemployment_rate
        median_household_income bachelors_degree_rate no_health_insurance_rate
        age_under_5_rate age_over_61_rate poc_rate
        white_rate black_rate asian_rate aian_rate napi_rate hispanic_rate
        other_race_rate mixed_race_rate
        renter_rate owner_rate
      ]

      demographic_cols_active = demographic_range_filters.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
      demographic_cols_active ||= params[:density_min].present? || params[:density_max].present?
      demographic_cols_active ||= params[:most_common_rate_tier].present?

      if demographic_cols_active
        scope, joined = left_join_once(scope, joined, :demographic)
      end

      demographic_range_filters.each do |col|
        if params[:"#{col}_min"].present?
          scope = scope.where("demographics.#{col} >= ?", params[:"#{col}_min"].to_d)
        end
        if params[:"#{col}_max"].present?
          scope = scope.where("demographics.#{col} <= ?", params[:"#{col}_max"].to_d)
        end
      end

      scope = scope.where("demographics.population_density >= ?", params[:density_min].to_d) if params[:density_min].present?
      scope = scope.where("demographics.population_density <= ?", params[:density_max].to_d) if params[:density_max].present?
      scope = scope.where("demographics.most_common_rate_tier = ?", params[:most_common_rate_tier]) if params[:most_common_rate_tier].present?

      # --- Environmental justice range filters ---
      ej_range_filters = %i[cejst_disadvantaged_pct svi_overall_pctl cvi_overall_score]

      if ej_range_filters.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
        scope, joined = left_join_once(scope, joined, :environmental_justice)
      end

      ej_range_filters.each do |col|
        if params[:"#{col}_min"].present?
          scope = scope.where("environmental_justices.#{col} >= ?", params[:"#{col}_min"].to_d)
        end
        if params[:"#{col}_max"].present?
          scope = scope.where("environmental_justices.#{col} <= ?", params[:"#{col}_max"].to_d)
        end
      end

      # --- Funding range filters ---
      funding_range_filters = %i[times_funded total_srf_assistance total_principal_forgiveness]

      if funding_range_filters.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
        scope, joined = left_join_once(scope, joined, :funding_summary)
      end

      funding_range_filters.each do |col|
        if params[:"#{col}_min"].present?
          scope = scope.where("funding_summaries.#{col} >= ?", params[:"#{col}_min"].to_d)
        end
        if params[:"#{col}_max"].present?
          scope = scope.where("funding_summaries.#{col} <= ?", params[:"#{col}_max"].to_d)
        end
      end

      # --- Watershed hazard range filters ---
      hazard_range_filters = %i[
        num_facilities permit_effluent_violations open_underground_storage_tanks
        risk_management_plan_facilities impaired_streams_303d
      ]

      if hazard_range_filters.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
        scope, joined = left_join_once(scope, joined, :watershed_hazard)
      end

      hazard_range_filters.each do |col|
        if params[:"#{col}_min"].present?
          scope = scope.where("watershed_hazards.#{col} >= ?", params[:"#{col}_min"].to_i)
        end
        if params[:"#{col}_max"].present?
          scope = scope.where("watershed_hazards.#{col} <= ?", params[:"#{col}_max"].to_i)
        end
      end

      # --- Trend range filters ---
      trend_range_filters = %i[population_pct_change mhi_pct_change]

      if trend_range_filters.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
        scope, joined = left_join_once(scope, joined, :trend_datum)
      end

      trend_range_filters.each do |col|
        if params[:"#{col}_min"].present?
          scope = scope.where("trend_data.#{col} >= ?", params[:"#{col}_min"].to_d)
        end
        if params[:"#{col}_max"].present?
          scope = scope.where("trend_data.#{col} <= ?", params[:"#{col}_max"].to_d)
        end
      end

      # --- Place geographic filter (via place_system_crosswalks) ---
      if params[:place_geoid].present?
        pwsids = PlaceSystemCrosswalk.where(geoid: params[:place_geoid]).select(:pwsid)
        scope = scope.where(pwsid: pwsids)
      end

      # --- County geographic filter (spatial subquery via centroid) ---
      if params[:county_geoid].present?
        scope = scope.where(<<~SQL.squish, params[:county_geoid])
          public_water_systems.pwsid IN (
            SELECT sag.pwsid
            FROM service_area_geometries sag
            JOIN cartographic_counties cc ON ST_Intersects(sag.centroid, cc.geom)
            WHERE cc.geoid = ?
          )
        SQL
      end

      # --- Bounding box geographic filter ---
      if params[:bounds].present?
        west, south, east, north = params[:bounds].split(",").map(&:to_f)
        scope, joined = left_join_once(scope, joined, :service_area_geometry)
        scope = scope.where(
          "ST_Intersects(service_area_geometries.geom, ST_MakeEnvelope(?, ?, ?, ?, 4326))",
          west, south, east, north
        )
      end

      scope
    end

    private

    # Adds a left outer join for the given association at most once per query,
    # preventing duplicate joins when multiple filters reference the same table.
    def left_join_once(scope, joined, assoc)
      return [ scope, joined ] if joined.include?(assoc)

      [ scope.left_joins(assoc), joined | [ assoc ] ]
    end
  end
end
