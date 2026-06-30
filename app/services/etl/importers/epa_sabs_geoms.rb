module Etl
  module Importers
    class EpaSabsGeoms < Etl::FileImporter
      require "digest"

      BATCH_SIZE = 500

      # Overrides FileImporter#call to stream the GeoJSON from disk one feature
      # at a time via a SAX parser, keeping only a single BATCH_SIZE window of
      # rows in memory at any point. This is necessary because the source file
      # is ~1 GB — loading it into a Ruby string or object tree causes an OOM.
      def call
        filename = @file_url.split("/").last

        unless needs_import?
          log("[ETL] #{filename}: skipped (unchanged since last import)")
          return skipped_result
        end

        log("[ETL] #{filename}: downloading...")
        started_at = Time.current
        tempfile = stream_to_tempfile(@file_url)
        elapsed = (Time.current - started_at).round(1)
        size_mb = (tempfile.size / 1_048_576.0).round(1)
        log("[ETL] #{filename}: downloaded #{size_mb} MB in #{elapsed}s, streaming import...")

        count, changed_pwsids, previous_geometry_bboxes = stream_import(tempfile)
        raise EmptyImportError, "Import produced 0 rows for #{@file_url}" if count.zero?

        record_import
        log("[ETL] #{filename}: import complete")
        imported_result(
          changed_pwsids: changed_pwsids,
          changed_layers: changed_pwsids.any? ? %w[pws places] : [],
          geometry_changed: changed_pwsids.any?,
          previous_geometry_bboxes: previous_geometry_bboxes
        )
      ensure
        tempfile&.close!
      end

      def import!(rows)
        conn = ApplicationRecord.connection
        changed_pwsids = []
        previous_geometry_bboxes = []

        rows.each_slice(BATCH_SIZE) do |batch|
          changed_batch, existing = changed_geometry_batch(batch)
          next if changed_batch.empty?

          changed_pwsids.concat(changed_batch.pluck(:pwsid))
          previous_geometry_bboxes.concat(changed_batch.filter_map { |row| existing.dig(row[:pwsid], :bbox) })
          conn.transaction do
            changed_batch.each do |row|
              conn.exec_query(
                <<~SQL,
                  INSERT INTO service_area_geometries (pwsid, geom, geom_digest, created_at, updated_at)
                  VALUES ($1, ST_GeomFromGeoJSON($2), $3, NOW(), NOW())
                  ON CONFLICT (pwsid) DO UPDATE
                    SET geom = EXCLUDED.geom,
                        geom_digest = EXCLUDED.geom_digest,
                        updated_at = NOW()
                SQL
                "EpaSabsGeoms#import!",
                [
                  ActiveRecord::Relation::QueryAttribute.new("pwsid", row[:pwsid], ActiveModel::Type::String.new),
                  ActiveRecord::Relation::QueryAttribute.new("geom_json", row[:geom_json], ActiveModel::Type::String.new),
                  ActiveRecord::Relation::QueryAttribute.new("geom_digest", row[:geom_digest], ActiveModel::Type::String.new)
                ]
              )
            end
          end
        end

        imported_result(
          changed_pwsids: changed_pwsids,
          changed_layers: changed_pwsids.any? ? %w[pws places] : [],
          geometry_changed: changed_pwsids.any?,
          previous_geometry_bboxes: previous_geometry_bboxes
        )
      end

      # SAX-style handler that yields one complete feature Hash at a time as
      # Oj streams through the FeatureCollection. Only the current feature's
      # data is held in memory — coordinates are never accumulated globally.
      class FeatureHandler < Oj::Saj
        def initialize(&on_feature)
          @on_feature = on_feature
          @in_features = false  # true once we've entered the "features" array
          @collecting = false   # true while parsing a single feature object
          @stack = []           # reconstruction stack for the current feature
        end

        def hash_start(key)
          if @collecting
            h = {}
            attach(key, h)
            @stack.push(h)
          elsif @in_features
            @collecting = true
            @stack = [{}]
          end
        end

        def hash_end(_key)
          return unless @collecting

          completed = @stack.pop
          if @stack.empty?
            @on_feature.call(completed)
            @collecting = false
          end
        end

        def array_start(key)
          if @collecting
            a = []
            attach(key, a)
            @stack.push(a)
          elsif key == "features"
            @in_features = true
          end
        end

        def array_end(key)
          @stack.pop if @collecting && @stack.last.is_a?(Array)
          @in_features = false if key == "features"
        end

        def add_value(value, key)
          attach(key, value) if @collecting
        end

        def error(message, line, column)
          raise "GeoJSON parse error at #{line}:#{column}: #{message}"
        end

        private

        def attach(key, value)
          parent = @stack.last
          case parent
          when Hash then parent[key] = value
          when Array then parent << value
          end
        end
      end

      private

      def stream_import(tempfile)
        count = 0
        batch = []
        changed_pwsids = []
        previous_geometry_bboxes = []

        handler = FeatureHandler.new do |feature|
          batch << {
            pwsid: feature.dig("properties", "pwsid"),
            geom_json: Oj.dump(feature["geometry"])
          }
          count += 1

          if batch.size >= BATCH_SIZE
            result = import!(batch)
            validate_import_result!(result)
            changed_pwsids.concat(result.changed_pwsids)
            previous_geometry_bboxes.concat(result.previous_geometry_bboxes)
            batch.clear
          end
        end

        File.open(tempfile.path) { |f| Oj.saj_parse(handler, f) }
        unless batch.empty?
          result = import!(batch)
          validate_import_result!(result)
          changed_pwsids.concat(result.changed_pwsids)
          previous_geometry_bboxes.concat(result.previous_geometry_bboxes)
        end
        [count, changed_pwsids.uniq, previous_geometry_bboxes.uniq]
      end

      def changed_geometry_batch(batch)
        rows = batch.map { |row| row.merge(geom_digest: geometry_digest(row)) }
        existing = existing_geometry_metadata(rows.pluck(:pwsid))
        changed_rows = rows.reject { |row| existing.dig(row[:pwsid], :geom_digest) == row[:geom_digest] }

        [changed_rows, existing]
      end

      def geometry_digest(row)
        Digest::SHA256.hexdigest(row[:geom_json].to_s)
      end

      def existing_geometry_metadata(pwsids)
        rows = ApplicationRecord.connection.exec_query(
          <<~SQL,
            SELECT
              pwsid,
              geom_digest,
              ST_XMin(geom::box3d) AS west,
              ST_YMin(geom::box3d) AS south,
              ST_XMax(geom::box3d) AS east,
              ST_YMax(geom::box3d) AS north
            FROM service_area_geometries
            WHERE pwsid = ANY($1::text[])
          SQL
          "EpaSabsGeoms#existing_geometry_metadata",
          [
            ActiveRecord::Relation::QueryAttribute.new(
              "pwsids",
              Array(pwsids).compact.uniq,
              ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(ActiveModel::Type::String.new)
            )
          ]
        )

        rows.each_with_object({}) do |row, metadata|
          bbox = %w[west south east north].map { |key| row[key]&.to_f }
          metadata[row.fetch("pwsid")] = {
            geom_digest: row["geom_digest"],
            bbox: bbox.all? ? bbox : nil
          }
        end
      end
    end
  end
end
