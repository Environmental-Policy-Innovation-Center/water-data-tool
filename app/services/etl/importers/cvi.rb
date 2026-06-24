require "csv"

module Etl
  module Importers
    class Cvi < Etl::FileImporter
      include Etl::TypeCaster

      def parse(content)
        rows = []
        CSV.parse(content, headers: true) do |row|
          rows << {
            pwsid: row["pwsid"],
            cvi_redlining: cast_dec(row["pw_int_hh.redlining"]),
            cvi_life_expectancy: cast_dec(row["pw_int_pop.life_expectancy"]),
            cvi_cancer_risk: cast_dec(row["pw_int_pop.cancer"]),
            cvi_overall_score: cast_score(row["a_int.overall_cvi_score"]),
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        rows
      end

      def import!(rows)
        EnvironmentalJustice.upsert_all(rows, unique_by: :pwsid)
        imported_result
      end
    end
  end
end
