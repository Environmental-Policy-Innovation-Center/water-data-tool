require "csv"

module Etl
  module Importers
    class EpaSabsXwalk < Etl::FileImporter
      include Etl::TypeCaster

      def parse(content)
        rows = []
        CSV.parse(content, headers: true) do |row|
          rows << {
            pwsid: row["pwsid"],
            total_population: cast_int(row["total_pop"]),
            population_density: cast_dec(row["epic_pop_density"]),
            median_household_income: cast_int(row["mhi"]),
            household_income_lowest_quintile: cast_int(row["hh_inc_lowest_quintile"]),
            poverty_rate: cast_dec(row["hh_below_pov_per"]),
            population_in_poverty_rate: cast_dec(row["pop_in_pov_per"]),
            unemployment_rate: cast_dec(row["laborforce_unemployed_per"]),
            bachelors_degree_rate: cast_dec(row["bachelors_per"]),
            no_health_insurance_rate: cast_dec(row["no_health_insurance_per"]),
            age_under_5_rate: cast_dec(row["ageunder_5_per"]),
            age_over_61_rate: cast_dec(row["age_over_61_per"]),
            white_rate: cast_dec(row["white_alone_per"]),
            black_rate: cast_dec(row["black_alone_per"]),
            asian_rate: cast_dec(row["asian_alone_per"]),
            aian_rate: cast_dec(row["AIAN_alone_per"]),
            napi_rate: cast_dec(row["NAPI_alone_per"]),
            hispanic_rate: cast_dec(row["hisp_alone_per"]),
            other_race_rate: cast_dec(row["other_alone_per"]),
            mixed_race_rate: cast_dec(row["mixed_alone_per"]),
            poc_rate: cast_dec(row["poc_alone_per"]),
            renter_rate: cast_dec(row["hh_rent_home_per"]),
            owner_rate: cast_dec(row["hh_own_home_per"]),
            water_rate_under_125: cast_dec(row["water_rate_less_125_per"]),
            water_rate_125_249: cast_dec(row["water_rate_between_125_249_per"]),
            water_rate_250_499: cast_dec(row["water_rate_between_250_499_per"]),
            water_rate_500_749: cast_dec(row["water_rate_between_500_749_per"]),
            water_rate_750_999: cast_dec(row["water_rate_between_750_999_per"]),
            water_rate_over_1000: cast_dec(row["water_rate_over_1000_per"]),
            most_common_rate_tier: row["most_common_rate_tidy"],
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        rows
      end

      def import!(rows)
        Demographic.upsert_all(rows, unique_by: :pwsid)
      end
    end
  end
end
