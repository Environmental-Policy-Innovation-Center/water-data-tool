require "csv"

module Etl
  module Importers
    class Ejscreen < Etl::FileImporter
      include Etl::TypeCaster

      def parse(content)
        rows = []
        CSV.parse(content, headers: true) do |row|
          rows << {
            pwsid: row["pwsid"],
            ejscreen_drinking_water: cast_dec(row["a_int.dwater"]),
            ejscreen_disability_rate: cast_dec(row["pw_ext_pop.disability"]),
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
