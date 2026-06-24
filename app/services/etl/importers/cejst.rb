require "csv"

module Etl
  module Importers
    class Cejst < Etl::FileImporter
      include Etl::TypeCaster

      def parse(content)
        rows = []
        CSV.parse(content, headers: true) do |row|
          rows << {
            pwsid: row["pwsid"],
            cejst_disadvantaged_pct: cast_score(row["a_int.identified_as_disadvantaged"]),
            cejst_lead_paint_indicator: cast_int(row["pw_int_hh.percent_pre_1960s_housing_lead_paint_indicator"]),
            cejst_low_life_expectancy_pctl: cast_dec(row["pw_int_pop.low_life_expectancy_percentile"]),
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        rows
      end

      def import!(rows)
        EnvironmentalJustice.upsert_all(rows, unique_by: :pwsid)
        Etl::ImportResult.imported(file_key: file_key)
      end
    end
  end
end
