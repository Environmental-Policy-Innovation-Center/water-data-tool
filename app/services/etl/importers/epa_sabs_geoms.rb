module Etl
  module Importers
    class EpaSabsGeoms < Etl::FileImporter
      BATCH_SIZE = 500

      # Overrides FileImporter#call to stream the GeoJSON from disk one feature
      # at a time via a SAX parser, keeping only a single BATCH_SIZE window of
      # rows in memory at any point. This is necessary because the source file
      # is ~1 GB — loading it into a Ruby string or object tree causes an OOM.
      def call
        filename = @file_url.split("/").last

        unless needs_import?
          log("[ETL] #{filename}: skipped (unchanged since last import)")
          return :skipped
        end

        log("[ETL] #{filename}: downloading...")
        started_at = Time.current
        tempfile = stream_to_tempfile(@file_url)
        elapsed = (Time.current - started_at).round(1)
        size_mb = (tempfile.size / 1_048_576.0).round(1)
        log("[ETL] #{filename}: downloaded #{size_mb} MB in #{elapsed}s, streaming import...")

        count = stream_import(tempfile)
        raise EmptyImportError, "Import produced 0 rows for #{@file_url}" if count.zero?

        record_import
        log("[ETL] #{filename}: import complete")
        :imported
      ensure
        tempfile&.close!
      end

      def import!(rows)
        conn = ApplicationRecord.connection

        rows.each_slice(BATCH_SIZE) do |batch|
          conn.transaction do
            batch.each do |row|
              conn.exec_query(
                <<~SQL,
                  INSERT INTO service_area_geometries (pwsid, geom, created_at, updated_at)
                  VALUES ($1, ST_GeomFromGeoJSON($2), NOW(), NOW())
                  ON CONFLICT (pwsid) DO UPDATE
                    SET geom       = EXCLUDED.geom,
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

        handler = FeatureHandler.new do |feature|
          batch << {
            pwsid: feature.dig("properties", "pwsid"),
            geom_json: Oj.dump(feature["geometry"])
          }
          count += 1

          if batch.size >= BATCH_SIZE
            import!(batch)
            batch.clear
          end
        end

        File.open(tempfile.path) { |f| Oj.saj_parse(handler, f) }
        import!(batch) unless batch.empty?
        count
      end
    end
  end
end
