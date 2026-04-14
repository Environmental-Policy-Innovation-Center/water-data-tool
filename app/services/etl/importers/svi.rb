require "csv"

module Etl
  module Importers
    class Svi < Etl::FileImporter
      include Etl::TypeCaster

      def parse(content)
        rows = []
        CSV.parse(content, headers: true) do |row|
          rows << {
            pwsid: row["pwsid"],
            svi_overall_pctl: cast_score(row["pw_int_pop.rpl_themes"]),
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        rows
      end

      def import!(rows)
        EnvironmentalJustice.upsert_all(rows, unique_by: :pwsid)
      end
    end
  end
end
