class PublicWaterSystemDetailSerializer
  def initialize(pws)
    @pws = pws
  end

  def serialize
    PublicWaterSystemSerializer.new(@pws).serialize.merge(
      demographic: serialize_demographic,
      violations_summary: serialize_violations_summary,
      environmental_justice: serialize_environmental_justice,
      funding_summary: serialize_funding_summary,
      watershed_hazard: serialize_watershed_hazard,
      boil_water_summary: serialize_boil_water_summary,
      trend_datum: serialize_trend_datum
    )
  end

  private

  # All has_one associations can be nil when ETL has not yet populated data for
  # a given system. Each serialize_* method returns nil in that case rather than
  # raising NoMethodError.

  def serialize_demographic
    return nil if @pws.demographic.nil?

    d = @pws.demographic
    {
      total_population: d.total_population,
      population_density: d.population_density,
      median_household_income: d.median_household_income,
      household_income_lowest_quintile: d.household_income_lowest_quintile,
      poverty_rate: d.poverty_rate,
      population_in_poverty_rate: d.population_in_poverty_rate,
      unemployment_rate: d.unemployment_rate,
      bachelors_degree_rate: d.bachelors_degree_rate,
      no_health_insurance_rate: d.no_health_insurance_rate,
      age_under_5_rate: d.age_under_5_rate,
      age_over_61_rate: d.age_over_61_rate,
      poc_rate: d.poc_rate,
      white_rate: d.white_rate,
      black_rate: d.black_rate,
      asian_rate: d.asian_rate,
      aian_rate: d.aian_rate,
      napi_rate: d.napi_rate,
      hispanic_rate: d.hispanic_rate,
      other_race_rate: d.other_race_rate,
      mixed_race_rate: d.mixed_race_rate,
      renter_rate: d.renter_rate,
      owner_rate: d.owner_rate,
      water_rate_under_125: d.water_rate_under_125,
      water_rate_125_249: d.water_rate_125_249,
      water_rate_250_499: d.water_rate_250_499,
      water_rate_500_749: d.water_rate_500_749,
      water_rate_750_999: d.water_rate_750_999,
      water_rate_over_1000: d.water_rate_over_1000,
      most_common_rate_tier: d.most_common_rate_tier
    }
  end

  def serialize_violations_summary
    return nil if @pws.violations_summary.nil?

    vs = @pws.violations_summary
    {
      health_violations_5yr: vs.health_violations_5yr,
      groundwater_rule_5yr: vs.groundwater_rule_5yr,
      surface_water_treatment_5yr: vs.surface_water_treatment_5yr,
      lead_and_copper_5yr: vs.lead_and_copper_5yr,
      radionuclides_5yr: vs.radionuclides_5yr,
      inorganic_chemicals_5yr: vs.inorganic_chemicals_5yr,
      synthetic_organic_chemicals_5yr: vs.synthetic_organic_chemicals_5yr,
      volatile_organic_chemicals_5yr: vs.volatile_organic_chemicals_5yr,
      total_coliform_5yr: vs.total_coliform_5yr,
      stage_1_disinfectants_5yr: vs.stage_1_disinfectants_5yr,
      stage_2_disinfectants_5yr: vs.stage_2_disinfectants_5yr,
      paperwork_violations_5yr: vs.paperwork_violations_5yr,
      total_violations_5yr: vs.total_violations_5yr,
      health_violations_10yr: vs.health_violations_10yr,
      groundwater_rule_10yr: vs.groundwater_rule_10yr,
      surface_water_treatment_10yr: vs.surface_water_treatment_10yr,
      lead_and_copper_10yr: vs.lead_and_copper_10yr,
      radionuclides_10yr: vs.radionuclides_10yr,
      inorganic_chemicals_10yr: vs.inorganic_chemicals_10yr,
      synthetic_organic_chemicals_10yr: vs.synthetic_organic_chemicals_10yr,
      volatile_organic_chemicals_10yr: vs.volatile_organic_chemicals_10yr,
      total_coliform_10yr: vs.total_coliform_10yr,
      stage_1_disinfectants_10yr: vs.stage_1_disinfectants_10yr,
      stage_2_disinfectants_10yr: vs.stage_2_disinfectants_10yr,
      paperwork_violations_10yr: vs.paperwork_violations_10yr,
      total_violations_10yr: vs.total_violations_10yr,
      violations_all_years: vs.violations_all_years
    }
  end

  def serialize_environmental_justice
    return nil if @pws.environmental_justice.nil?

    ej = @pws.environmental_justice
    {
      cejst_disadvantaged_pct: ej.cejst_disadvantaged_pct,
      cejst_lead_paint_indicator: ej.cejst_lead_paint_indicator,
      cejst_low_life_expectancy_pctl: ej.cejst_low_life_expectancy_pctl,
      svi_overall_pctl: ej.svi_overall_pctl,
      ejscreen_drinking_water: ej.ejscreen_drinking_water,
      ejscreen_disability_rate: ej.ejscreen_disability_rate,
      cvi_overall_score: ej.cvi_overall_score,
      cvi_redlining: ej.cvi_redlining,
      cvi_life_expectancy: ej.cvi_life_expectancy,
      cvi_cancer_risk: ej.cvi_cancer_risk
    }
  end

  def serialize_funding_summary
    return nil if @pws.funding_summary.nil?

    fs = @pws.funding_summary
    {
      times_funded: fs.times_funded,
      total_srf_assistance: fs.total_srf_assistance,
      median_srf_assistance: fs.median_srf_assistance,
      total_principal_forgiveness: fs.total_principal_forgiveness
    }
  end

  def serialize_watershed_hazard
    return nil if @pws.watershed_hazard.nil?

    wh = @pws.watershed_hazard
    {
      num_facilities: wh.num_facilities,
      npdes_permits: wh.npdes_permits,
      permit_effluent_violations: wh.permit_effluent_violations,
      open_underground_storage_tanks: wh.open_underground_storage_tanks,
      risk_management_plan_facilities: wh.risk_management_plan_facilities,
      impaired_streams_303d: wh.impaired_streams_303d
    }
  end

  def serialize_boil_water_summary
    return nil if @pws.boil_water_summary.nil?

    bws = @pws.boil_water_summary
    {
      total_notices: bws.total_notices,
      first_advisory_date: bws.first_advisory_date,
      last_advisory_date: bws.last_advisory_date,
      date_range_display: bws.date_range_display,
      tooltip_text: bws.tooltip_text,
      state_reporting_year_min: bws.state_reporting_year_min,
      state_reporting_year_max: bws.state_reporting_year_max
    }
  end

  def serialize_trend_datum
    return nil if @pws.trend_datum.nil?

    td = @pws.trend_datum
    {
      population_pct_change: td.population_pct_change,
      population_pct_change_capped: td.population_pct_change_capped,
      population_change_flag: td.population_change_flag,
      mhi_pct_change: td.mhi_pct_change,
      mhi_pct_change_capped: td.mhi_pct_change_capped,
      income_change_flag: td.income_change_flag,
      households_pct_change: td.households_pct_change,
      poverty_pct_change: td.poverty_pct_change,
      unemployment_pct_change: td.unemployment_pct_change,
      lowest_quintile_pct_change: td.lowest_quintile_pct_change,
      population_in_poverty_pct_change: td.population_in_poverty_pct_change,
      poc_pct_change: td.poc_pct_change
    }
  end
end
