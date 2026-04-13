require "csv"

namespace :db do
  namespace :seed do
    desc "Seed database with water system data for given states: bin/rails db:seed:states[VT,RI]"
    task :states, [ :states ] => :environment do |_, args|
      abort "Usage: bin/rails db:seed:states[VT,RI]" if args[:states].blank?

      states = ([ args[:states] ] + args.extras).compact.map(&:strip).map(&:upcase)
      dir = Rails.root.join("db/seeds/csv")

      puts "→ Seeding #{states.join(', ')}..."

      # Collect the pwsids we care about upfront — used to filter all subsequent files
      target_pwsids = Set.new

      # ---------------------------------------------------------------------------
      # 1. PublicWaterSystem — core attributes from epa_sabs.csv
      # ---------------------------------------------------------------------------
      pws_rows = []
      each_row(dir, "epa_sabs.csv", states) do |row|
        target_pwsids << row["pwsid"]
        pws_rows << {
          pwsid:                    row["pwsid"],
          pws_name:                 row["pws_name"],
          stusps:                   row["pwsid"][0, 2],
          primacy_agency:           row["primacy_agency"],
          pop_cat_5:                row["pop_cat_5"],
          population_served_count:  cast_int(row["population_served_count"]),
          service_connections_count: cast_int(row["service_connections_count"]),
          service_area_type:        row["service_area_type"],
          symbology_field:          row["symbology_field"],
          detailed_facility_report: row["detailed_facility_report"],
          ewg_report_link:          row["ewg_report_link"],
          area_sq_miles:            cast_dec(row["epic_area_mi2"]),
          created_at:               Time.current,
          updated_at:               Time.current
        }
      end

      PublicWaterSystem.upsert_all(pws_rows, unique_by: :pwsid) if pws_rows.any?
      puts "  PublicWaterSystem:    #{pws_rows.size}"

      # ---------------------------------------------------------------------------
      # 2. PublicWaterSystem (remaining attrs) + ViolationsSummary — from sdwis_viols.csv
      # ---------------------------------------------------------------------------
      pws_updates = []
      viol_rows = []

      each_row(dir, "sdwis_viols.csv", states) do |row|
        next unless target_pwsids.include?(row["pwsid"])

        pws_updates << {
          pwsid:                       row["pwsid"],
          gw_sw_code:                  row["gw_sw_code"],
          primary_source_code:         row["primary_source_code"],
          first_reported_date:         row["first_reported_date"],
          years_operating:             cast_int(row["years_operating"]),
          owner_type:                  row["owner_type"],
          primacy_type:                row["primacy_type"],
          is_grant_eligible:           cast_bool(row["is_grant_eligible_ind"]),
          is_wholesaler:               cast_bool(row["is_wholesaler_ind"]),
          is_school_or_daycare:        cast_bool(row["is_school_or_daycare_ind"]),
          source_water_protection_code: row["source_water_protection_code"],
          phone_number:                row["phone_number"],
          open_health_viol:            row["open_health_viol"],
          updated_at:                  Time.current
        }

        viol_rows << {
          pwsid:                             row["pwsid"],
          lead_and_copper_5yr:               cast_int(row["lead_and_copper_rule_healthbased_5yr"]),
          radionuclides_5yr:                 cast_int(row["radionuclides_and_revised_rad_rule_healthbased_5yr"]),
          groundwater_rule_5yr:              cast_int(row["groundwater_rule_healthbased_5yr"]),
          surface_water_treatment_5yr:       cast_int(row["surface_water_treatment_rules_healthbased_5yr"]),
          total_coliform_5yr:                cast_int(row["total_coliform_rules_healthbased_5yr"]),
          inorganic_chemicals_5yr:           cast_int(row["inorganic_chemicals_healthbased_5yr"]),
          stage_1_disinfectants_5yr:         cast_int(row["stage_1_disinfectants_and_byproducts_rule_healthbased_5yr"]),
          stage_2_disinfectants_5yr:         cast_int(row["stage_2_disinfectants_and_byproducts_rule_healthbased_5yr"]),
          synthetic_organic_chemicals_5yr:   cast_int(row["synthetic_organic_chemicals_healthbased_5yr"]),
          volatile_organic_chemicals_5yr:    cast_int(row["volatile_organic_chemicals_healthbased_5yr"]),
          health_violations_5yr:             cast_int(row["health_viols_5yr"]),
          paperwork_violations_5yr:          cast_int(row["paperwork_viols_5yr"]),
          total_violations_5yr:              cast_int(row["total_viols_5yr"]),
          lead_and_copper_10yr:              cast_int(row["lead_and_copper_rule_healthbased_10yr"]),
          radionuclides_10yr:                cast_int(row["radionuclides_and_revised_rad_rule_healthbased_10yr"]),
          groundwater_rule_10yr:             cast_int(row["groundwater_rule_healthbased_10yr"]),
          surface_water_treatment_10yr:      cast_int(row["surface_water_treatment_rules_healthbased_10yr"]),
          total_coliform_10yr:               cast_int(row["total_coliform_rules_healthbased_10yr"]),
          inorganic_chemicals_10yr:          cast_int(row["inorganic_chemicals_healthbased_10yr"]),
          stage_1_disinfectants_10yr:        cast_int(row["stage_1_disinfectants_and_byproducts_rule_healthbased_10yr"]),
          stage_2_disinfectants_10yr:        cast_int(row["stage_2_disinfectants_and_byproducts_rule_healthbased_10yr"]),
          synthetic_organic_chemicals_10yr:  cast_int(row["synthetic_organic_chemicals_healthbased_10yr"]),
          volatile_organic_chemicals_10yr:   cast_int(row["volatile_organic_chemicals_healthbased_10yr"]),
          health_violations_10yr:            cast_int(row["health_viols_10yr"]),
          paperwork_violations_10yr:         cast_int(row["paperwork_viols_10yr"]),
          total_violations_10yr:             cast_int(row["total_viols_10yr"]),
          violations_all_years:              cast_int(row["violations_all_years"]),
          created_at:                        Time.current,
          updated_at:                        Time.current
        }
      end

      PublicWaterSystem.upsert_all(pws_updates, unique_by: :pwsid) if pws_updates.any?
      ViolationsSummary.upsert_all(viol_rows, unique_by: :pwsid) if viol_rows.any?
      puts "  ViolationsSummary:    #{viol_rows.size}"

      # ---------------------------------------------------------------------------
      # 3. Demographic — from epa_sabs_xwalk.csv
      # ---------------------------------------------------------------------------
      demo_rows = []
      each_row(dir, "epa_sabs_xwalk.csv", states) do |row|
        next unless target_pwsids.include?(row["pwsid"])

        demo_rows << {
          pwsid:                          row["pwsid"],
          total_population:               cast_int(row["total_pop"]),
          population_density:             cast_dec(row["epic_pop_density"]),
          median_household_income:        cast_int(row["mhi"]),
          household_income_lowest_quintile: cast_int(row["hh_inc_lowest_quintile"]),
          poverty_rate:                   cast_dec(row["hh_below_pov_per"]),
          population_in_poverty_rate:     cast_dec(row["pop_in_pov_per"]),
          unemployment_rate:              cast_dec(row["laborforce_unemployed_per"]),
          bachelors_degree_rate:          cast_dec(row["bachelors_per"]),
          no_health_insurance_rate:       cast_dec(row["no_health_insurance_per"]),
          age_under_5_rate:               cast_dec(row["ageunder_5_per"]),
          age_over_61_rate:               cast_dec(row["age_over_61_per"]),
          white_rate:                     cast_dec(row["white_alone_per"]),
          black_rate:                     cast_dec(row["black_alone_per"]),
          asian_rate:                     cast_dec(row["asian_alone_per"]),
          aian_rate:                      cast_dec(row["AIAN_alone_per"]),
          napi_rate:                      cast_dec(row["NAPI_alone_per"]),
          hispanic_rate:                  cast_dec(row["hisp_alone_per"]),
          other_race_rate:                cast_dec(row["other_alone_per"]),
          mixed_race_rate:                cast_dec(row["mixed_alone_per"]),
          poc_rate:                       cast_dec(row["poc_alone_per"]),
          renter_rate:                    cast_dec(row["hh_rent_home_per"]),
          owner_rate:                     cast_dec(row["hh_own_home_per"]),
          water_rate_under_125:           cast_dec(row["water_rate_less_125_per"]),
          water_rate_125_249:             cast_dec(row["water_rate_between_125_249_per"]),
          water_rate_250_499:             cast_dec(row["water_rate_between_250_499_per"]),
          water_rate_500_749:             cast_dec(row["water_rate_between_500_749_per"]),
          water_rate_750_999:             cast_dec(row["water_rate_between_750_999_per"]),
          water_rate_over_1000:           cast_dec(row["water_rate_over_1000_per"]),
          most_common_rate_tier:          row["most_common_rate_tidy"],
          created_at:                     Time.current,
          updated_at:                     Time.current
        }
      end

      Demographic.upsert_all(demo_rows, unique_by: :pwsid) if demo_rows.any?
      puts "  Demographic:          #{demo_rows.size}"

      # ---------------------------------------------------------------------------
      # 4. TrendDatum — from xwalk_pct_change_10yr.csv
      # ---------------------------------------------------------------------------
      trend_rows = []
      each_row(dir, "xwalk_pct_change_10yr.csv", states) do |row|
        next unless target_pwsids.include?(row["pwsid"])

        trend_rows << {
          pwsid:                            row["pwsid"],
          population_pct_change:            cast_dec(row["total_pop_pct_change_2011_2021"]),
          unemployment_pct_change:          cast_dec(row["laborforce_unemployed_pct_change_2011_2021"]),
          mhi_pct_change:                   cast_dec(row["mhi_pct_change_2011_2021"]),
          lowest_quintile_pct_change:       cast_dec(row["hh_inc_lowest_quintile_pct_change_2011_2021"]),
          households_pct_change:            cast_dec(row["hh_total_pct_change_2011_2021"]),
          poverty_pct_change:               cast_dec(row["hh_below_pov_pct_change_2011_2021"]),
          poc_pct_change:                   cast_dec(row["poc_alone_per_pct_change_2011_2021"]),
          population_in_poverty_pct_change: cast_dec(row["pop_in_pov_per_pct_change_2011_2021"]),
          income_change_flag:               row["income_change_flag"],
          population_change_flag:           row["population_change_flag"],
          population_pct_change_capped:     cast_dec(row["total_pop_pct_change_2011_2021_cap"]),
          mhi_pct_change_capped:            cast_dec(row["mhi_pct_change_2011_2021_cap"]),
          created_at:                       Time.current,
          updated_at:                       Time.current
        }
      end

      TrendDatum.upsert_all(trend_rows, unique_by: :pwsid) if trend_rows.any?
      puts "  TrendDatum:           #{trend_rows.size}"

      # ---------------------------------------------------------------------------
      # 5. EnvironmentalJustice — merge 4 files into one table
      # ---------------------------------------------------------------------------
      ej = Hash.new { |h, k| h[k] = { pwsid: k, created_at: Time.current, updated_at: Time.current } }

      each_row(dir, "cejst.csv", states) do |row|
        next unless target_pwsids.include?(row["pwsid"])
        ej[row["pwsid"]].merge!(
          cejst_disadvantaged_pct:        cast_score(row["a_int.identified_as_disadvantaged"]),
          cejst_lead_paint_indicator:     cast_int(row["pw_int_hh.percent_pre_1960s_housing_lead_paint_indicator"]),
          cejst_low_life_expectancy_pctl: cast_dec(row["pw_int_pop.low_life_expectancy_percentile"]),
        )
      end

      each_row(dir, "ejscreen.csv", states) do |row|
        next unless target_pwsids.include?(row["pwsid"])
        ej[row["pwsid"]].merge!(
          ejscreen_drinking_water: cast_dec(row["a_int.dwater"]),
          ejscreen_disability_rate: cast_dec(row["pw_ext_pop.disability"]),
        )
      end

      each_row(dir, "svi.csv", states) do |row|
        next unless target_pwsids.include?(row["pwsid"])
        ej[row["pwsid"]].merge!(
          svi_overall_pctl: cast_score(row["pw_int_pop.rpl_themes"]),
        )
      end

      each_row(dir, "cvi.csv", states) do |row|
        next unless target_pwsids.include?(row["pwsid"])
        ej[row["pwsid"]].merge!(
          cvi_redlining:    cast_dec(row["pw_int_hh.redlining"]),
          cvi_life_expectancy: cast_dec(row["pw_int_pop.life_expectancy"]),
          cvi_cancer_risk:  cast_dec(row["pw_int_pop.cancer"]),
          cvi_overall_score: cast_score(row["a_int.overall_cvi_score"]),
        )
      end

      ej_rows = ej.values
      EnvironmentalJustice.upsert_all(ej_rows, unique_by: :pwsid) if ej_rows.any?
      puts "  EnvironmentalJustice: #{ej_rows.size}"

      # ---------------------------------------------------------------------------
      # 6. BoilWaterSummary — from national_bwn_highlevel_summary.csv
      # ---------------------------------------------------------------------------
      bwn_rows = []
      CSV.foreach(dir.join("national_bwn_highlevel_summary.csv"), headers: true) do |row|
        next unless target_pwsids.include?(row["pwsid"])

        bwn_rows << {
          pwsid:                    row["pwsid"],
          first_advisory_date:      row["date_of_first_advisory"],
          last_advisory_date:       row["date_of_last_advisory"],
          total_notices:            cast_int(row["total_bwn"]),
          state_reporting_year_min: row["min_reporting_year_for_state"],
          state_reporting_year_max: row["max_reporting_year_for_state"],
          state:                    row["state"],
          tooltip_text:             row["data_tool_tip"],
          download_url:             row["download_link"],
          date_range_display:       row["clean_date_range"],
          created_at:               Time.current,
          updated_at:               Time.current
        }
      end

      BoilWaterSummary.upsert_all(bwn_rows, unique_by: :pwsid) if bwn_rows.any?
      puts "  BoilWaterSummary:     #{bwn_rows.size}"

      # ---------------------------------------------------------------------------
      # 7. FundingSummary — from pwsid_funded_highlevel_summary.csv
      # ---------------------------------------------------------------------------
      funding_rows = []
      CSV.foreach(dir.join("pwsid_funded_highlevel_summary.csv"), headers: true) do |row|
        next unless target_pwsids.include?(row["pwsid"])

        funding_rows << {
          pwsid:                      row["pwsid"],
          times_funded:               cast_int(row["times_funded"]),
          total_srf_assistance:       cast_dec(row["total_srf_assistance"]),
          median_srf_assistance:      cast_dec(row["median_srf_assistance"]),
          total_principal_forgiveness: cast_dec(row["total_principal_forgiveness"]),
          created_at:                 Time.current,
          updated_at:                 Time.current
        }
      end

      FundingSummary.upsert_all(funding_rows, unique_by: :pwsid) if funding_rows.any?
      puts "  FundingSummary:       #{funding_rows.size}"

      # ---------------------------------------------------------------------------
      # 8. WatershedHazard — aggregate multi-row HUC12 data per pwsid
      # ---------------------------------------------------------------------------
      hazard_agg = {}
      CSV.foreach(dir.join("pwsid_npdes_usts_rmps_imp.csv"), headers: true) do |row|
        next unless target_pwsids.include?(row["pwsid"])

        pwsid = row["pwsid"]
        hazard_agg[pwsid] ||= { pwsid: pwsid, num_facilities: 0, npdes_permits: 0,
                                 permit_effluent_violations: 0, open_underground_storage_tanks: 0,
                                 risk_management_plan_facilities: 0, impaired_streams_303d: 0,
                                 created_at: Time.current, updated_at: Time.current }
        hazard_agg[pwsid][:num_facilities]                  += cast_int(row["num_facilities"]).to_i
        hazard_agg[pwsid][:npdes_permits]                   += cast_int(row["npdes_permits"]).to_i
        hazard_agg[pwsid][:permit_effluent_violations]      += cast_int(row["total_permit_eff_viols"]).to_i
        hazard_agg[pwsid][:open_underground_storage_tanks]  += cast_int(row["total_open_usts"]).to_i
        hazard_agg[pwsid][:risk_management_plan_facilities] += cast_int(row["total_facilities_w_rmps"]).to_i
        hazard_agg[pwsid][:impaired_streams_303d]           += cast_int(row["streams_303d_list"]).to_i
      end

      hazard_rows = hazard_agg.values
      WatershedHazard.upsert_all(hazard_rows, unique_by: :pwsid) if hazard_rows.any?
      puts "  WatershedHazard:      #{hazard_rows.size}"

      puts "✓ Done."
    end
  end
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def each_row(dir, filename, states)
  CSV.foreach(dir.join(filename), headers: true) do |row|
    yield row if states.any? { |s| row["pwsid"]&.start_with?(s) }
  end
end

def cast_int(val)
  return nil if val.nil? || val.strip == "" || val.strip.upcase == "NA"

  val.strip.to_i
end

def cast_dec(val)
  return nil if val.nil? || val.strip == "" || val.strip.upcase == "NA"

  val.strip.to_d
end

def cast_bool(val)
  return nil if val.nil? || val.strip == ""

  val.strip.upcase == "Y"
end

def cast_score(val)
  return nil if val.nil? || val.strip == "" || val.strip.upcase == "NA"

  (val.strip.to_f * 100).round(2)
end
