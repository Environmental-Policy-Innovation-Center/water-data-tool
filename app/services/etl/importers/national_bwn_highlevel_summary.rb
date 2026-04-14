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
            first_advisory_date: row["date_of_first_advisory"],
            last_advisory_date: row["date_of_last_advisory"],
            total_notices: cast_int(row["total_bwn"]),
            state_reporting_year_min: row["min_reporting_year_for_state"],
            state_reporting_year_max: row["max_reporting_year_for_state"],
            state: row["state"],
            tooltip_text: row["data_tool_tip"],
            download_url: row["download_link"],
            date_range_display: row["clean_date_range"],
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        rows
      end

      def import!(rows)
        BoilWaterSummary.upsert_all(rows, unique_by: :pwsid)
      end
    end
  end
end
