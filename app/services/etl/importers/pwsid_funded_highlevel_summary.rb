require "csv"

module Etl
  module Importers
    class PwsidFundedHighlevelSummary < Etl::FileImporter
      include Etl::TypeCaster

      def parse(content)
        rows = []
        CSV.parse(content, headers: true) do |row|
          rows << {
            pwsid: row["pwsid"],
            times_funded: cast_int(row["times_funded"]),
            total_srf_assistance: cast_dec(row["total_srf_assistance"]),
            median_srf_assistance: cast_dec(row["median_srf_assistance"]),
            total_principal_forgiveness: cast_dec(row["total_principal_forgiveness"]),
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        rows
      end

      def import!(rows)
        FundingSummary.upsert_all(rows, unique_by: :pwsid)
        Etl::ImportResult.imported(file_key: file_key)
      end
    end
  end
end
