module Etl
  module Importers
    class EpaSabsGeoms < Etl::FileImporter
      # Number of features per transaction batch.
      BATCH_SIZE = 500

      def parse(content)
        geojson = JSON.parse(content)
        geojson["features"].map do |feature|
          {
            pwsid: feature.dig("properties", "pwsid"),
            geom_json: feature["geometry"].to_json
          }
        end
      end

      def import!(rows)
        conn = ApplicationRecord.connection

        # Each row uses fully parameterized SQL — no string interpolation of
        # user-controlled data. Batched in transactions to keep throughput high.
        rows.each_slice(BATCH_SIZE) do |batch|
          conn.transaction do
            batch.each do |row|
              conn.exec_query(
                <<~SQL,
                  INSERT INTO service_area_geometries (pwsid, geom, created_at, updated_at)
                  VALUES ($1, ST_GeomFromGeoJSON($2), NOW(), NOW())
                  ON CONFLICT (pwsid) DO UPDATE
                    SET geom     = EXCLUDED.geom,
                        updated_at = NOW()
                SQL
                "EpaSabsGeoms#import!",
                [
                  ActiveRecord::Relation::QueryAttribute.new("pwsid", row[:pwsid], ActiveModel::Type::String.new),
                  ActiveRecord::Relation::QueryAttribute.new("geom_json", row[:geom_json], ActiveModel::Type::String.new)
                ]
              )
            end
          end
        end
      end
    end
  end
end
