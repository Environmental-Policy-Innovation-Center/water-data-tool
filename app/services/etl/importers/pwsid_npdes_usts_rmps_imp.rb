require "csv"

module Etl
  module Importers
    class PwsidNpdesUstsRmpsImp < Etl::FileImporter
      include Etl::TypeCaster

      # Pre-aggregates multi-row HUC12 data into one row per pwsid,
      # matching the GROUP BY pwsid, SUM(...) that the legacy app did at query time.
      def parse(content)
        aggregated = {}

        CSV.parse(content, headers: true) do |row|
          pwsid = row["pwsid"]
          aggregated[pwsid] ||= {
            pwsid: pwsid,
            num_facilities: 0,
            npdes_permits: 0,
            permit_effluent_violations: 0,
            open_underground_storage_tanks: 0,
            risk_management_plan_facilities: 0,
            impaired_streams_303d: 0,
            created_at: Time.current,
            updated_at: Time.current
          }

          aggregated[pwsid][:num_facilities] += cast_int(row["num_facilities"]).to_i
          aggregated[pwsid][:npdes_permits] += cast_int(row["npdes_permits"]).to_i
          aggregated[pwsid][:permit_effluent_violations] += cast_int(row["total_permit_eff_viols"]).to_i
          aggregated[pwsid][:open_underground_storage_tanks] += cast_int(row["total_open_usts"]).to_i
          aggregated[pwsid][:risk_management_plan_facilities] += cast_int(row["total_facilities_w_rmps"]).to_i
          aggregated[pwsid][:impaired_streams_303d] += cast_int(row["streams_303d_list"]).to_i
        end

        aggregated.values
      end

      def import!(rows)
        WatershedHazard.upsert_all(rows, unique_by: :pwsid)
        Etl::ImportResult.imported(file_key: file_key)
      end
    end
  end
end
