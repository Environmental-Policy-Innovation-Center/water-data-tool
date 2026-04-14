require "csv"

module Etl
  module Importers
    class SdwisViols < Etl::FileImporter
      include Etl::TypeCaster

      # Returns a hash with :pws_rows and :viol_rows because this single
      # source file feeds two tables.
      def parse(content)
        pws_rows = []
        viol_rows = []

        CSV.parse(content, headers: true) do |row|
          pws_rows << {
            pwsid: row["pwsid"],
            gw_sw_code: row["gw_sw_code"],
            primary_source_code: row["primary_source_code"],
            first_reported_date: row["first_reported_date"],
            years_operating: cast_int(row["years_operating"]),
            owner_type: row["owner_type"],
            primacy_type: row["primacy_type"],
            is_grant_eligible: cast_bool(row["is_grant_eligible_ind"]),
            is_wholesaler: cast_bool(row["is_wholesaler_ind"]),
            is_school_or_daycare: cast_bool(row["is_school_or_daycare_ind"]),
            source_water_protection_code: row["source_water_protection_code"],
            phone_number: row["phone_number"],
            open_health_viol: row["open_health_viol"],
            updated_at: Time.current
          }

          viol_rows << {
            pwsid: row["pwsid"],
            health_violations_5yr: cast_int(row["health_viols_5yr"]),
            groundwater_rule_5yr: cast_int(row["groundwater_rule_healthbased_5yr"]),
            surface_water_treatment_5yr: cast_int(row["surface_water_treatment_rules_healthbased_5yr"]),
            lead_and_copper_5yr: cast_int(row["lead_and_copper_rule_healthbased_5yr"]),
            radionuclides_5yr: cast_int(row["radionuclides_and_revised_rad_rule_healthbased_5yr"]),
            inorganic_chemicals_5yr: cast_int(row["inorganic_chemicals_healthbased_5yr"]),
            synthetic_organic_chemicals_5yr: cast_int(row["synthetic_organic_chemicals_healthbased_5yr"]),
            volatile_organic_chemicals_5yr: cast_int(row["volatile_organic_chemicals_healthbased_5yr"]),
            total_coliform_5yr: cast_int(row["total_coliform_rules_healthbased_5yr"]),
            stage_1_disinfectants_5yr: cast_int(row["stage_1_disinfectants_and_byproducts_rule_healthbased_5yr"]),
            stage_2_disinfectants_5yr: cast_int(row["stage_2_disinfectants_and_byproducts_rule_healthbased_5yr"]),
            paperwork_violations_5yr: cast_int(row["paperwork_viols_5yr"]),
            total_violations_5yr: cast_int(row["total_viols_5yr"]),
            health_violations_10yr: cast_int(row["health_viols_10yr"]),
            groundwater_rule_10yr: cast_int(row["groundwater_rule_healthbased_10yr"]),
            surface_water_treatment_10yr: cast_int(row["surface_water_treatment_rules_healthbased_10yr"]),
            lead_and_copper_10yr: cast_int(row["lead_and_copper_rule_healthbased_10yr"]),
            radionuclides_10yr: cast_int(row["radionuclides_and_revised_rad_rule_healthbased_10yr"]),
            inorganic_chemicals_10yr: cast_int(row["inorganic_chemicals_healthbased_10yr"]),
            synthetic_organic_chemicals_10yr: cast_int(row["synthetic_organic_chemicals_healthbased_10yr"]),
            volatile_organic_chemicals_10yr: cast_int(row["volatile_organic_chemicals_healthbased_10yr"]),
            total_coliform_10yr: cast_int(row["total_coliform_rules_healthbased_10yr"]),
            stage_1_disinfectants_10yr: cast_int(row["stage_1_disinfectants_and_byproducts_rule_healthbased_10yr"]),
            stage_2_disinfectants_10yr: cast_int(row["stage_2_disinfectants_and_byproducts_rule_healthbased_10yr"]),
            paperwork_violations_10yr: cast_int(row["paperwork_viols_10yr"]),
            total_violations_10yr: cast_int(row["total_viols_10yr"]),
            violations_all_years: cast_int(row["violations_all_years"]),
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        {pws_rows: pws_rows, viol_rows: viol_rows}
      end

      def import!(rows)
        PublicWaterSystem.upsert_all(rows[:pws_rows], unique_by: :pwsid)
        ViolationsSummary.upsert_all(rows[:viol_rows], unique_by: :pwsid)
      end

      private

      # Override: rows is a Hash, not an Array — validate both sub-collections.
      def validate!(rows)
        if rows[:pws_rows].empty? || rows[:viol_rows].empty?
          raise Etl::FileImporter::EmptyImportError, "Import produced 0 rows for #{@file_url}"
        end
      end
    end
  end
end
