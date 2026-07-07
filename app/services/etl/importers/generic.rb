require "csv"

module Etl
  module Importers
    # Importer driven entirely by the manifest (FieldRegistry.etl_mapping). Handles the
    # common "flat map" shape: parse a CSV into one {db_column => cast(row[header])} row
    # per source row, keyed by pwsid, then upsert into a single model.
    #
    # Source files that aggregate, derive columns, or stream geometry keep their custom
    # importer (see docs/CONFIG_AUDIT.md §8.1). The file is identified from its URL, so one
    # class serves every flat-map file; its column map comes from the manifest, not code.
    class Generic < Etl::FileImporter
      include Etl::TypeCaster

      # Manifest `cast:` token → TypeCaster method. A nil token means raw passthrough.
      CASTERS = {
        integer: :cast_int,
        decimal: :cast_dec,
        string: :cast_string,
        score: :cast_score,
        bool: :cast_bool
      }.freeze

      def parse(content)
        columns = column_mappings
        now = Time.current

        rows = []
        CSV.parse(content, headers: true) do |row|
          attrs = {pwsid: row["pwsid"], created_at: now, updated_at: now}
          columns.each { |col| attrs[col[:db_column]] = cast(col[:cast], row[col[:header]]) }
          rows << attrs
        end
        rows
      end

      def import!(rows)
        model.upsert_all(rows, unique_by: :pwsid)
        imported_result
      end

      private

      def model = mapping[:model]

      def column_mappings = mapping[:columns]

      # Resolves this file's manifest source mapping once: the destination model class and its
      # column list [{db_column:, header:, cast:}, ...], read from FieldRegistry.etl_mapping.
      # Generic ingestion targets a single model, so the manifest must map this file to one.
      def mapping
        @mapping ||= begin
          by_model = FieldRegistry.etl_mapping.fetch(file_key.to_sym) do
            raise KeyError, "no manifest source mapping for #{file_key.inspect}"
          end
          unless by_model.size == 1
            raise "generic importer expects one destination model for #{file_key}, got #{by_model.keys}"
          end
          model_sym, columns = by_model.first
          {model: FieldRegistry.model_class(model_sym), columns: columns}
        end
      end

      def cast(token, value)
        return value if token.nil?
        public_send(CASTERS.fetch(token), value)
      end
    end
  end
end
