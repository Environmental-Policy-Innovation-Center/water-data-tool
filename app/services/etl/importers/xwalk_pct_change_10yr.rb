require "csv"

module Etl
  module Importers
    class XwalkPctChange10yr < Etl::FileImporter
      include Etl::TypeCaster

      def parse(content)
        rows = []
        CSV.parse(content, headers: true) do |row|
          rows << {
            pwsid: row["pwsid"],
            population_pct_change: cast_dec(row["total_pop_pct_change_2011_2021"]),
            unemployment_pct_change: cast_dec(row["laborforce_unemployed_pct_change_2011_2021"]),
            mhi_pct_change: cast_dec(row["mhi_pct_change_2011_2021"]),
            lowest_quintile_pct_change: cast_dec(row["hh_inc_lowest_quintile_pct_change_2011_2021"]),
            households_pct_change: cast_dec(row["hh_total_pct_change_2011_2021"]),
            poverty_pct_change: cast_dec(row["hh_below_pov_pct_change_2011_2021"]),
            poc_pct_change: cast_dec(row["poc_alone_per_pct_change_2011_2021"]),
            population_in_poverty_pct_change: cast_dec(row["pop_in_pov_per_pct_change_2011_2021"]),
            income_change_flag: row["income_change_flag"],
            population_change_flag: row["population_change_flag"],
            population_pct_change_capped: cast_dec(row["total_pop_pct_change_2011_2021_cap"]),
            mhi_pct_change_capped: cast_dec(row["mhi_pct_change_2011_2021_cap"]),
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        rows
      end

      def import!(rows)
        TrendDatum.upsert_all(rows, unique_by: :pwsid)
      end
    end
  end
end
