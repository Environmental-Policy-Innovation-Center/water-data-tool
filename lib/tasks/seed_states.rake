require "csv"
require "net/http"
require "json"
require "fileutils"
require_relative "../../app/services/etl/type_caster"

# Helpers are namespaced to avoid polluting the global Object space.
module SeedImport
  extend Etl::TypeCaster

  def self.each_row(dir, filename, states, &block)
    CSV.foreach(dir.join(filename), headers: true) do |row|
      block.call(row) if states.any? { |s| row["pwsid"]&.start_with?(s) }
    end
  end

  # Download each source file to the cache directory using the S3 base URL.
  # Returns the cache directory path. Skips files that already exist locally.
  def self.download_data_files(base_url, cache_dir)
    FileUtils.mkdir_p(cache_dir)
    base = base_url.chomp("/")

    Etl::Importer::FILE_IMPORTERS.each_key do |key|
      ext = Etl::Importer::FILE_EXTENSIONS[key]
      url = "#{base}/#{key}#{ext}"
      filename = "#{key}#{ext}"
      local_path = cache_dir.join(filename)

      if local_path.exist?
        puts "  #{filename} (cached)"
        next
      end

      puts "  Downloading #{filename}..."
      download_with_progress(url, local_path)
    end

    cache_dir
  end

  def self.build_pws_row(row)
    {
      pwsid: row["pwsid"],
      pws_name: cast_string(row["pws_name"]),
      stusps: row["pwsid"][0, 2],
      primacy_agency: cast_string(row["primacy_agency"]),
      pop_cat_5: cast_string(row["pop_cat_5"]),
      population_served_count: cast_int(row["population_served_count"]),
      service_connections_count: cast_int(row["service_connections_count"]),
      service_area_type: cast_string(row["service_area_type"]),
      symbology_field: cast_string(row["symbology_field"]),
      detailed_facility_report: cast_string(row["detailed_facility_report"]),
      ewg_report_link: cast_string(row["ewg_report_link"]),
      area_sq_miles: cast_dec(row["epic_area_mi2"]),
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  # Stream-downloads a file with progress reporting for large files.
  def self.download_with_progress(url, destination)
    uri = URI.parse(url)
    raise "Only HTTPS URLs are permitted" unless uri.is_a?(URI::HTTPS)

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Get.new(uri)
      http.request(request) do |response|
        raise "Download failed: #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

        total = response["Content-Length"]&.to_i
        downloaded = 0

        File.open(destination, "wb") do |file|
          response.read_body do |chunk|
            file.write(chunk)
            downloaded += chunk.size
            if total && total > 10_000_000 # Show progress for files >10MB
              pct = (downloaded.to_f / total * 100).round(1)
              print "\r    #{pct}% (#{(downloaded / 1_048_576.0).round(1)}MB / #{(total / 1_048_576.0).round(1)}MB)"
            end
          end
        end
        puts if total && total > 10_000_000
      end
    end
  end
end

namespace :db do
  namespace :seed do
    desc <<~DESC
      Seed database with water system data for given states.
      Downloads data from S3 if not cached locally.

      Usage:
        bin/rails db:seed:states[VT,RI]
        bin/rails 'db:seed:states[CT,MA,ME,NH,RI,VT]'
    DESC
    task :states, [:states] => :environment do |_, args|
      abort "Usage: bin/rails db:seed:states[VT,RI]" if args[:states].blank?

      states = ([args[:states]] + args.extras).compact.map(&:strip).map(&:upcase)

      puts "→ Seeding #{states.join(", ")}..."

      # ── Download source files from S3 ───────────────────────────────────────
      base_url = ENV.fetch("ETL_SOURCE_URL") {
        abort "ETL_SOURCE_URL not set. Add it to .env."
      }
      dir = SeedImport.download_data_files(base_url, Rails.root.join("tmp/seeds"))

      # Collect the pwsids we care about upfront — used to filter all subsequent files
      target_pwsids = Set.new

      # ---------------------------------------------------------------------------
      # 1. PublicWaterSystem — core attributes from epa_sabs.csv
      # ---------------------------------------------------------------------------
      pws_rows = []
      SeedImport.each_row(dir, "epa_sabs.csv", states) do |row|
        target_pwsids << row["pwsid"]
        pws_rows << SeedImport.build_pws_row(row)
      end

      PublicWaterSystem.upsert_all(pws_rows, unique_by: :pwsid) if pws_rows.any?
      puts "  PublicWaterSystem:    #{pws_rows.size}"

      # ---------------------------------------------------------------------------
      # 1b. Tribal systems — collect from sdwis_viols.csv and add to target_pwsids
      #
      # Tribal systems use numeric EPA region codes as pwsid prefixes (e.g. "08...")
      # instead of two-letter state codes, so they are never matched by each_row's
      # state-prefix filter above. A second pass adds them explicitly.
      # ---------------------------------------------------------------------------
      tribal_pwsids = Set.new
      CSV.foreach(dir.join("sdwis_viols.csv"), headers: true) do |row|
        tribal_pwsids << row["pwsid"] if row["primacy_type"] == "Tribal"
      end
      tribal_pwsids -= target_pwsids

      tribal_pws_rows = []
      CSV.foreach(dir.join("epa_sabs.csv"), headers: true) do |row|
        next unless tribal_pwsids.include?(row["pwsid"])
        target_pwsids << row["pwsid"]
        tribal_pws_rows << SeedImport.build_pws_row(row)
      end

      PublicWaterSystem.upsert_all(tribal_pws_rows, unique_by: :pwsid) if tribal_pws_rows.any?
      puts "  PublicWaterSystem (tribal): #{tribal_pws_rows.size}"

      # target_pwsids now contains both state-prefixed and tribal pwsids — sole filter for all steps below.

      # ---------------------------------------------------------------------------
      # 2. PublicWaterSystem (remaining attrs) + ViolationsSummary — from sdwis_viols.csv
      # ---------------------------------------------------------------------------
      pws_updates = []
      viol_rows = []

      CSV.foreach(dir.join("sdwis_viols.csv"), headers: true) do |row|
        next unless target_pwsids.include?(row["pwsid"])

        pws_updates << {
          pwsid: row["pwsid"],
          gw_sw_code: SeedImport.cast_string(row["gw_sw_code"]),
          primary_source_code: SeedImport.cast_string(row["primary_source_code"]),
          first_reported_date: SeedImport.cast_string(row["first_reported_date"]),
          years_operating: SeedImport.cast_int(row["years_operating"]),
          owner_type: SeedImport.cast_string(row["owner_type"]),
          primacy_type: SeedImport.cast_string(row["primacy_type"]),
          is_grant_eligible: SeedImport.cast_bool(row["is_grant_eligible_ind"]),
          is_wholesaler: SeedImport.cast_bool(row["is_wholesaler_ind"]),
          is_school_or_daycare: SeedImport.cast_bool(row["is_school_or_daycare_ind"]),
          source_water_protection_code: SeedImport.cast_string(row["source_water_protection_code"]),
          phone_number: SeedImport.cast_string(row["phone_number"]),
          open_health_viol: SeedImport.cast_string(row["open_health_viol"]),
          updated_at: Time.current
        }

        viol_rows << {
          pwsid: row["pwsid"],
          lead_and_copper_5yr: SeedImport.cast_int(row["lead_and_copper_rule_healthbased_5yr"]),
          radionuclides_5yr: SeedImport.cast_int(row["radionuclides_and_revised_rad_rule_healthbased_5yr"]),
          groundwater_rule_5yr: SeedImport.cast_int(row["groundwater_rule_healthbased_5yr"]),
          surface_water_treatment_5yr: SeedImport.cast_int(row["surface_water_treatment_rules_healthbased_5yr"]),
          total_coliform_5yr: SeedImport.cast_int(row["total_coliform_rules_healthbased_5yr"]),
          inorganic_chemicals_5yr: SeedImport.cast_int(row["inorganic_chemicals_healthbased_5yr"]),
          stage_1_disinfectants_5yr: SeedImport.cast_int(row["stage_1_disinfectants_and_byproducts_rule_healthbased_5yr"]),
          stage_2_disinfectants_5yr: SeedImport.cast_int(row["stage_2_disinfectants_and_byproducts_rule_healthbased_5yr"]),
          synthetic_organic_chemicals_5yr: SeedImport.cast_int(row["synthetic_organic_chemicals_healthbased_5yr"]),
          volatile_organic_chemicals_5yr: SeedImport.cast_int(row["volatile_organic_chemicals_healthbased_5yr"]),
          health_violations_5yr: SeedImport.cast_int(row["health_viols_5yr"]),
          paperwork_violations_5yr: SeedImport.cast_int(row["paperwork_viols_5yr"]),
          total_violations_5yr: SeedImport.cast_int(row["total_viols_5yr"]),
          lead_and_copper_10yr: SeedImport.cast_int(row["lead_and_copper_rule_healthbased_10yr"]),
          radionuclides_10yr: SeedImport.cast_int(row["radionuclides_and_revised_rad_rule_healthbased_10yr"]),
          groundwater_rule_10yr: SeedImport.cast_int(row["groundwater_rule_healthbased_10yr"]),
          surface_water_treatment_10yr: SeedImport.cast_int(row["surface_water_treatment_rules_healthbased_10yr"]),
          total_coliform_10yr: SeedImport.cast_int(row["total_coliform_rules_healthbased_10yr"]),
          inorganic_chemicals_10yr: SeedImport.cast_int(row["inorganic_chemicals_healthbased_10yr"]),
          stage_1_disinfectants_10yr: SeedImport.cast_int(row["stage_1_disinfectants_and_byproducts_rule_healthbased_10yr"]),
          stage_2_disinfectants_10yr: SeedImport.cast_int(row["stage_2_disinfectants_and_byproducts_rule_healthbased_10yr"]),
          synthetic_organic_chemicals_10yr: SeedImport.cast_int(row["synthetic_organic_chemicals_healthbased_10yr"]),
          volatile_organic_chemicals_10yr: SeedImport.cast_int(row["volatile_organic_chemicals_healthbased_10yr"]),
          health_violations_10yr: SeedImport.cast_int(row["health_viols_10yr"]),
          paperwork_violations_10yr: SeedImport.cast_int(row["paperwork_viols_10yr"]),
          total_violations_10yr: SeedImport.cast_int(row["total_viols_10yr"]),
          violations_all_years: SeedImport.cast_int(row["violations_all_years"]),
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      PublicWaterSystem.upsert_all(pws_updates, unique_by: :pwsid) if pws_updates.any?
      ViolationsSummary.upsert_all(viol_rows, unique_by: :pwsid) if viol_rows.any?
      puts "  ViolationsSummary:    #{viol_rows.size}"

      # ---------------------------------------------------------------------------
      # 3. Demographic — from epa_sabs_xwalk.csv
      # ---------------------------------------------------------------------------
      demo_rows = []
      CSV.foreach(dir.join("epa_sabs_xwalk.csv"), headers: true) do |row|
        next unless target_pwsids.include?(row["pwsid"])

        demo_rows << {
          pwsid: row["pwsid"],
          total_population: SeedImport.cast_int(row["total_pop"]),
          population_density: SeedImport.cast_dec(row["epic_pop_density"]),
          median_household_income: SeedImport.cast_int(row["mhi"]),
          household_income_lowest_quintile: SeedImport.cast_int(row["hh_inc_lowest_quintile"]),
          poverty_rate: SeedImport.cast_dec(row["hh_below_pov_per"]),
          population_in_poverty_rate: SeedImport.cast_dec(row["pop_in_pov_per"]),
          unemployment_rate: SeedImport.cast_dec(row["laborforce_unemployed_per"]),
          bachelors_degree_rate: SeedImport.cast_dec(row["bachelors_per"]),
          no_health_insurance_rate: SeedImport.cast_dec(row["no_health_insurance_per"]),
          age_under_5_rate: SeedImport.cast_dec(row["ageunder_5_per"]),
          age_over_61_rate: SeedImport.cast_dec(row["age_over_61_per"]),
          white_rate: SeedImport.cast_dec(row["white_alone_per"]),
          black_rate: SeedImport.cast_dec(row["black_alone_per"]),
          asian_rate: SeedImport.cast_dec(row["asian_alone_per"]),
          aian_rate: SeedImport.cast_dec(row["AIAN_alone_per"]),
          napi_rate: SeedImport.cast_dec(row["NAPI_alone_per"]),
          hispanic_rate: SeedImport.cast_dec(row["hisp_alone_per"]),
          other_race_rate: SeedImport.cast_dec(row["other_alone_per"]),
          mixed_race_rate: SeedImport.cast_dec(row["mixed_alone_per"]),
          poc_rate: SeedImport.cast_dec(row["poc_alone_per"]),
          renter_rate: SeedImport.cast_dec(row["hh_rent_home_per"]),
          owner_rate: SeedImport.cast_dec(row["hh_own_home_per"]),
          water_rate_under_125: SeedImport.cast_dec(row["water_rate_less_125_per"]),
          water_rate_125_249: SeedImport.cast_dec(row["water_rate_between_125_249_per"]),
          water_rate_250_499: SeedImport.cast_dec(row["water_rate_between_250_499_per"]),
          water_rate_500_749: SeedImport.cast_dec(row["water_rate_between_500_749_per"]),
          water_rate_750_999: SeedImport.cast_dec(row["water_rate_between_750_999_per"]),
          water_rate_over_1000: SeedImport.cast_dec(row["water_rate_over_1000_per"]),
          most_common_rate_tier: row["most_common_rate_tidy"], # CSV column is "most_common_rate_tidy" (source typo)
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      Demographic.upsert_all(demo_rows, unique_by: :pwsid) if demo_rows.any?
      puts "  Demographic:          #{demo_rows.size}"

      # ---------------------------------------------------------------------------
      # 4. TrendDatum — from xwalk_pct_change_10yr.csv
      # ---------------------------------------------------------------------------
      trend_rows = []
      CSV.foreach(dir.join("xwalk_pct_change_10yr.csv"), headers: true) do |row|
        next unless target_pwsids.include?(row["pwsid"])

        trend_rows << {
          pwsid: row["pwsid"],
          population_pct_change: SeedImport.cast_dec(row["total_pop_pct_change_2011_2021"]),
          unemployment_pct_change: SeedImport.cast_dec(row["laborforce_unemployed_pct_change_2011_2021"]),
          mhi_pct_change: SeedImport.cast_dec(row["mhi_pct_change_2011_2021"]),
          lowest_quintile_pct_change: SeedImport.cast_dec(row["hh_inc_lowest_quintile_pct_change_2011_2021"]),
          households_pct_change: SeedImport.cast_dec(row["hh_total_pct_change_2011_2021"]),
          poverty_pct_change: SeedImport.cast_dec(row["hh_below_pov_pct_change_2011_2021"]),
          poc_pct_change: SeedImport.cast_dec(row["poc_alone_per_pct_change_2011_2021"]),
          population_in_poverty_pct_change: SeedImport.cast_dec(row["pop_in_pov_per_pct_change_2011_2021"]),
          income_change_flag: SeedImport.cast_string(row["income_change_flag"]),
          population_change_flag: SeedImport.cast_string(row["population_change_flag"]),
          population_pct_change_capped: SeedImport.cast_dec(row["total_pop_pct_change_2011_2021_cap"]),
          mhi_pct_change_capped: SeedImport.cast_dec(row["mhi_pct_change_2011_2021_cap"]),
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      TrendDatum.upsert_all(trend_rows, unique_by: :pwsid) if trend_rows.any?
      puts "  TrendDatum:           #{trend_rows.size}"

      # ---------------------------------------------------------------------------
      # 5. EnvironmentalJustice — merge 4 files into one table
      # ---------------------------------------------------------------------------
      ej_defaults = {
        cejst_disadvantaged_pct: nil, cejst_lead_paint_indicator: nil, cejst_low_life_expectancy_pctl: nil,
        ejscreen_drinking_water: nil, ejscreen_disability_rate: nil,
        svi_overall_pctl: nil,
        cvi_redlining: nil, cvi_life_expectancy: nil, cvi_cancer_risk: nil, cvi_overall_score: nil
      }
      ej = Hash.new { |h, k| h[k] = {pwsid: k, created_at: Time.current, updated_at: Time.current}.merge(ej_defaults) }

      CSV.foreach(dir.join("cejst.csv"), headers: true) do |row|
        next unless target_pwsids.include?(row["pwsid"])
        ej[row["pwsid"]].merge!(
          cejst_disadvantaged_pct: SeedImport.cast_score(row["a_int.identified_as_disadvantaged"]),
          cejst_lead_paint_indicator: SeedImport.cast_int(row["pw_int_hh.percent_pre_1960s_housing_lead_paint_indicator"]),
          cejst_low_life_expectancy_pctl: SeedImport.cast_dec(row["pw_int_pop.low_life_expectancy_percentile"])
        )
      end

      CSV.foreach(dir.join("ejscreen.csv"), headers: true) do |row|
        next unless target_pwsids.include?(row["pwsid"])
        ej[row["pwsid"]].merge!(
          ejscreen_drinking_water: SeedImport.cast_dec(row["a_int.dwater"]),
          ejscreen_disability_rate: SeedImport.cast_dec(row["pw_ext_pop.disability"])
        )
      end

      CSV.foreach(dir.join("svi.csv"), headers: true) do |row|
        next unless target_pwsids.include?(row["pwsid"])
        ej[row["pwsid"]].merge!(
          svi_overall_pctl: SeedImport.cast_score(row["pw_int_pop.rpl_themes"])
        )
      end

      CSV.foreach(dir.join("cvi.csv"), headers: true) do |row|
        next unless target_pwsids.include?(row["pwsid"])
        ej[row["pwsid"]].merge!(
          cvi_redlining: SeedImport.cast_dec(row["pw_int_hh.redlining"]),
          cvi_life_expectancy: SeedImport.cast_dec(row["pw_int_pop.life_expectancy"]),
          cvi_cancer_risk: SeedImport.cast_dec(row["pw_int_pop.cancer"]),
          cvi_overall_score: SeedImport.cast_score(row["a_int.overall_cvi_score"])
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
          pwsid: row["pwsid"],
          first_advisory_date: SeedImport.cast_string(row["date_of_first_advisory"]),
          last_advisory_date: SeedImport.cast_string(row["date_of_last_advisory"]),
          total_notices: SeedImport.cast_int(row["total_bwn"]),
          state_reporting_year_min: SeedImport.cast_string(row["min_reporting_year_for_state"]),
          state_reporting_year_max: SeedImport.cast_string(row["max_reporting_year_for_state"]),
          state: SeedImport.cast_string(row["state"]),
          tooltip_text: SeedImport.cast_string(row["data_tool_tip"]),
          download_url: SeedImport.cast_string(row["download_link"]),
          date_range_display: SeedImport.cast_string(row["clean_date_range"]),
          created_at: Time.current,
          updated_at: Time.current
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
          pwsid: row["pwsid"],
          times_funded: SeedImport.cast_int(row["times_funded"]),
          total_srf_assistance: SeedImport.cast_dec(row["total_srf_assistance"]),
          median_srf_assistance: SeedImport.cast_dec(row["median_srf_assistance"]),
          total_principal_forgiveness: SeedImport.cast_dec(row["total_principal_forgiveness"]),
          created_at: Time.current,
          updated_at: Time.current
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
        hazard_agg[pwsid] ||= {pwsid: pwsid, num_facilities: 0, npdes_permits: 0,
                               permit_effluent_violations: 0, open_underground_storage_tanks: 0,
                               risk_management_plan_facilities: 0, impaired_streams_303d: 0,
                               created_at: Time.current, updated_at: Time.current}
        hazard_agg[pwsid][:num_facilities] += SeedImport.cast_int(row["num_facilities"]).to_i
        hazard_agg[pwsid][:npdes_permits] += SeedImport.cast_int(row["npdes_permits"]).to_i
        hazard_agg[pwsid][:permit_effluent_violations] += SeedImport.cast_int(row["total_permit_eff_viols"]).to_i
        hazard_agg[pwsid][:open_underground_storage_tanks] += SeedImport.cast_int(row["total_open_usts"]).to_i
        hazard_agg[pwsid][:risk_management_plan_facilities] += SeedImport.cast_int(row["total_facilities_w_rmps"]).to_i
        hazard_agg[pwsid][:impaired_streams_303d] += SeedImport.cast_int(row["streams_303d_list"]).to_i
      end

      hazard_rows = hazard_agg.values
      WatershedHazard.upsert_all(hazard_rows, unique_by: :pwsid) if hazard_rows.any?
      puts "  WatershedHazard:      #{hazard_rows.size}"

      # ---------------------------------------------------------------------------
      # 9. ServiceAreaGeometry — from epa_sabs_geoms.geojson (filtered to target states)
      # ---------------------------------------------------------------------------
      geojson_path = dir.join("epa_sabs_geoms.geojson")
      if geojson_path.exist?
        puts "  Loading geometries (filtering to #{states.join(", ")})..."

        geojson = JSON.parse(File.read(geojson_path))
        features = geojson["features"].select { |f| target_pwsids.include?(f.dig("properties", "pwsid")) }
        puts "  Found #{features.size} matching geometries out of #{geojson["features"].size} total"

        conn = ApplicationRecord.connection
        batch_size = 500
        inserted = 0

        features.each_slice(batch_size) do |batch|
          conn.transaction do
            batch.each do |feature|
              conn.exec_query(
                <<~SQL,
                  INSERT INTO service_area_geometries (pwsid, geom, created_at, updated_at)
                  VALUES ($1, ST_GeomFromGeoJSON($2), NOW(), NOW())
                  ON CONFLICT (pwsid) DO UPDATE
                    SET geom       = EXCLUDED.geom,
                        updated_at = NOW()
                SQL
                "SeedStates#geometries",
                [
                  ActiveRecord::Relation::QueryAttribute.new("pwsid", feature.dig("properties", "pwsid"), ActiveModel::Type::String.new),
                  ActiveRecord::Relation::QueryAttribute.new("geom_json", feature["geometry"].to_json, ActiveModel::Type::String.new)
                ]
              )
              inserted += 1
            end
          end
        end

        puts "  ServiceAreaGeometry:  #{inserted}"
      else
        puts "  ⚠ epa_sabs_geoms.geojson not found — skipping geometries"
      end

      # ---------------------------------------------------------------------------
      # 10. Cartographic boundaries — load if tables are empty
      # ---------------------------------------------------------------------------
      if CartographicState.count == 0
        puts "\n→ Loading cartographic boundaries..."
        Rake::Task["cartographic:load"].invoke
      else
        puts "\n  Cartographic boundaries: already loaded (#{CartographicState.count} states)"
      end

      # ---------------------------------------------------------------------------
      # 11. Post-import spatial steps
      # ---------------------------------------------------------------------------
      if ServiceAreaGeometry.count > 0
        puts "\n→ Running post-import spatial steps..."
        Etl::PostImportSteps.call
      end

      DataImport.create!(file_url: "seed:states[#{states.join(",")}]", imported_at: Time.current)

      puts "\n✓ Done. #{target_pwsids.size} water systems seeded for #{states.join(", ")}."
    end
  end
end
