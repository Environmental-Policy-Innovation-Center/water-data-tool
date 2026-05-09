class FilterParams
  PERMITTED = [
    # Direct categorical / boolean filters (public_water_systems)
    :gw_sw_code, :has_source_protection, :is_wholesaler, :is_school_or_daycare,
    :has_open_violations, :symbology_field, :state,

    # Geographic filters
    :place_geoid, :county_geoid, :bounds,

    # Range filters — public_water_systems
    :area_min, :area_max,

    # Range filters — demographics
    :density_min, :density_max, :no_rate_info,
    :total_population_min, :total_population_max,
    :poverty_rate_min, :poverty_rate_max,
    :population_in_poverty_rate_min, :population_in_poverty_rate_max,
    :unemployment_rate_min, :unemployment_rate_max,
    :median_household_income_min, :median_household_income_max,
    :bachelors_degree_rate_min, :bachelors_degree_rate_max,
    :no_health_insurance_rate_min, :no_health_insurance_rate_max,
    :age_under_5_rate_min, :age_under_5_rate_max,
    :age_over_61_rate_min, :age_over_61_rate_max,
    :poc_rate_min, :poc_rate_max,
    :white_rate_min, :white_rate_max,
    :black_rate_min, :black_rate_max,
    :asian_rate_min, :asian_rate_max,
    :aian_rate_min, :aian_rate_max,
    :napi_rate_min, :napi_rate_max,
    :hispanic_rate_min, :hispanic_rate_max,
    :other_race_rate_min, :other_race_rate_max,
    :mixed_race_rate_min, :mixed_race_rate_max,
    :renter_rate_min, :renter_rate_max,
    :owner_rate_min, :owner_rate_max,

    # Range filters — environmental_justices
    :cejst_disadvantaged_pct_min, :cejst_disadvantaged_pct_max,
    :svi_overall_pctl_min, :svi_overall_pctl_max,
    :cvi_overall_score_min, :cvi_overall_score_max,

    # Range filters — funding_summaries
    :times_funded_min, :times_funded_max,
    :total_srf_assistance_min, :total_srf_assistance_max,
    :total_principal_forgiveness_min, :total_principal_forgiveness_max,

    # Range filters — watershed_hazards
    :num_facilities_min, :num_facilities_max,
    :permit_effluent_violations_min, :permit_effluent_violations_max,
    :open_underground_storage_tanks_min, :open_underground_storage_tanks_max,
    :risk_management_plan_facilities_min, :risk_management_plan_facilities_max,
    :impaired_streams_303d_min, :impaired_streams_303d_max,

    # Range filters — trend_data
    :population_pct_change_min, :population_pct_change_max,
    :mhi_pct_change_min, :mhi_pct_change_max,

    # Range filters — violations_summaries (health sub-categories and paperwork)
    :boil_water_notices_min, :boil_water_notices_max,
    *Filterable::HEALTH_SUBCATS_ALL.flat_map { |col| [:"#{col}_min", :"#{col}_max"] },
    *Filterable::PAPERWORK_VIOLATIONS_COLS.flat_map { |col| [:"#{col}_min", :"#{col}_max"] },

    # Array params
    {owner_type: [], primacy_type: [], pop_cat_5: [], most_common_rate_tier: []}
  ].freeze

  def self.permit(params)
    params.permit(*PERMITTED)
  end
end
