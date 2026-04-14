require "csv"

module Etl
  module Importers
    class EpaSabs < Etl::FileImporter
      include Etl::TypeCaster

      def parse(content)
        rows = []
        CSV.parse(content, headers: true) do |row|
          rows << {
            pwsid: row["pwsid"],
            pws_name: row["pws_name"],
            stusps: row["pwsid"]&.[](0, 2),
            primacy_agency: row["primacy_agency"],
            pop_cat_5: row["pop_cat_5"],
            population_served_count: cast_int(row["population_served_count"]),
            service_connections_count: cast_int(row["service_connections_count"]),
            service_area_type: row["service_area_type"],
            symbology_field: row["symbology_field"],
            detailed_facility_report: row["detailed_facility_report"],
            ewg_report_link: row["ewg_report_link"],
            area_sq_miles: cast_dec(row["epic_area_mi2"]),
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        rows
      end

      def import!(rows)
        PublicWaterSystem.upsert_all(rows, unique_by: :pwsid)
      end
    end
  end
end
