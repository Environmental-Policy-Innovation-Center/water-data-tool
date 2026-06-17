require "csv"

module Etl
  module Importers
    class EpaSabs < Etl::FileImporter
      include Etl::TypeCaster

      MAP_FIELDS = %i[
        pws_name
        pop_cat_5
        population_served_count
        service_connections_count
        symbology_field
        stusps
        area_sq_miles
      ].freeze

      def parse(content)
        rows = []
        CSV.parse(content, headers: true) do |row|
          rows << {
            pwsid: row["pwsid"],
            pws_name: cast_string(row["pws_name"]),
            stusps: row["pwsid"]&.[](0, 2), # positional prefix; covers US territories (PR, VI, etc.) correctly
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
        rows
      end

      def import!(rows)
        changed_pwsids = changed_pwsids_for(rows)
        PublicWaterSystem.upsert_all(rows, unique_by: :pwsid)
        Etl::ImportResult.imported(
          file_key: file_key,
          changed_pwsids: changed_pwsids,
          changed_layers: changed_pwsids.any? ? ["pws"] : []
        )
      end

      private

      def changed_pwsids_for(rows)
        existing = PublicWaterSystem.where(pwsid: rows.pluck(:pwsid)).index_by(&:pwsid)

        rows.filter_map do |row|
          record = existing[row[:pwsid]]
          next row[:pwsid] unless record

          row[:pwsid] if MAP_FIELDS.any? { |field| record.public_send(field) != row[field] }
        end
      end
    end
  end
end
