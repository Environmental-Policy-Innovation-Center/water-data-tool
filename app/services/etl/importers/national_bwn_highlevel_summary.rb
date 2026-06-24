require "csv"

module Etl
  module Importers
    class NationalBwnHighlevelSummary < Etl::FileImporter
      include Etl::TypeCaster

      def parse(content)
        rows = []
        CSV.parse(content, headers: true) do |row|
          rows << {
            pwsid: row["pwsid"],
            first_advisory_date: cast_string(row["date_of_first_advisory"]),
            last_advisory_date: cast_string(row["date_of_last_advisory"]),
            total_notices: cast_int(row["total_bwn"]),
            state_reporting_year_min: cast_string(row["min_reporting_year_for_state"]),
            state_reporting_year_max: cast_string(row["max_reporting_year_for_state"]),
            state: cast_string(row["state"]),
            tooltip_text: cast_string(row["data_tool_tip"]),
            download_url: cast_string(row["download_link"]),
            date_range_display: cast_string(row["clean_date_range"]),
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        rows
      end

      def import!(rows)
        BoilWaterSummary.upsert_all(rows, unique_by: :pwsid)
        Etl::ImportResult.imported(file_key: file_key)
      end
    end
  end
end
