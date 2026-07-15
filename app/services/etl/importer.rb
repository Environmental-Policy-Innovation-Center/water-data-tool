module Etl
  # Orchestrates a full ETL run: check S3 Last-Modified headers, dispatch each
  # source file to its importer, and run post-import steps when geometry data
  # was refreshed.
  class Importer
    include Etl::HttpFetcher

    # Backward-compatible alias — existing code and specs reference this constant.
    InsecureUrlError = Etl::HttpFetcher::InsecureUrlError
    InvalidImportResultError = Class.new(StandardError)

    # Maps the filename stem to the importer class. Flat column→header→cast files are
    # driven entirely by the manifest (config/fields.yml) through Etl::Importers::Generic;
    # the rest keep a custom importer (see FieldRegistry.custom_imports for the reasons).
    FILE_IMPORTERS = {
      # Custom importers — structurally special (aggregation, geometry stream, derived columns).
      "epa_sabs" => Etl::Importers::EpaSabs,
      "epa_sabs_geoms" => Etl::Importers::EpaSabsGeoms,
      "sdwis_viols" => Etl::Importers::SdwisViols,
      "pwsid_npdes_usts_rmps_imp" => Etl::Importers::PwsidNpdesUstsRmpsImp,
      "sabs_pwsid_county" => Etl::Importers::SabsPwsidCounty,
      # Generic (manifest-driven) importers.
      "epa_sabs_xwalk" => Etl::Importers::Generic,
      "xwalk_pct_change_10yr" => Etl::Importers::Generic,
      "cejst" => Etl::Importers::Generic,
      "ejscreen" => Etl::Importers::Generic,
      "svi" => Etl::Importers::Generic,
      "cvi" => Etl::Importers::Generic,
      "national_bwn_highlevel_summary" => Etl::Importers::Generic,
      "pwsid_funded_highlevel_summary" => Etl::Importers::Generic,
      "awia_certification" => Etl::Importers::Generic
    }.freeze

    FILE_EXTENSIONS = {
      # Custom importers.
      "epa_sabs" => ".csv",
      "epa_sabs_geoms" => ".geojson",
      "sdwis_viols" => ".csv",
      "pwsid_npdes_usts_rmps_imp" => ".csv",
      "sabs_pwsid_county" => ".csv",
      # Generic (manifest-driven) importers.
      "epa_sabs_xwalk" => ".csv",
      "xwalk_pct_change_10yr" => ".csv",
      "cejst" => ".csv",
      "ejscreen" => ".csv",
      "svi" => ".csv",
      "cvi" => ".csv",
      "national_bwn_highlevel_summary" => ".csv",
      "pwsid_funded_highlevel_summary" => ".csv",
      "awia_certification" => ".csv"
    }.freeze

    def initialize(force: false, only: nil)
      @force = force
      @only = only
    end

    def call
      entries = build_file_entries
      import_results = []
      errors = []

      entries.each do |entry|
        file_key = entry["file_key"]
        next if @only && file_key != @only

        klass = FILE_IMPORTERS[file_key]

        begin
          result = klass.new(file_url: entry["http_path"], last_updated: entry["last_updated"], force: @force).call
          result = normalize_result(file_key, result)
          import_results << result if result.imported?
        rescue => e
          errors << {file_key: file_key, error: e}
          Rails.logger.error("[ETL] #{file_key} failed: #{e.class} — #{e.message}")
        end
      end

      import_cartographic_boundaries(import_results, errors)

      log_run_summary(import_results: import_results, errors: errors)
      Etl::PostImportSteps.call(import_results: import_results)

      errors
    end

    private

    # Cartographic boundaries (three ogr2ogr-loaded zips, not manifest files)
    # Runs as a peer step, checks its own source freshness and no-ops when unchanged.
    def import_cartographic_boundaries(import_results, errors)
      return unless @only.nil? || @only == CartographicBoundaries::IMPORT_FILE_URL

      result = CartographicBoundaries.load(force: @force)
      import_results << result if result.imported?
    rescue => e
      errors << {file_key: CartographicBoundaries::IMPORT_FILE_URL, error: e}
      Rails.logger.error("[ETL] #{CartographicBoundaries::IMPORT_FILE_URL} failed: #{e.class} — #{e.message}")
    end

    def normalize_result(file_key, result)
      return result if result.is_a?(Etl::ImportResult)

      raise InvalidImportResultError, "#{file_key} importer must return Etl::ImportResult, got #{result.class}"
    end

    def log_run_summary(import_results:, errors:)
      imported_files = import_results.map(&:file_key)
      changed_pwsids = import_results.flat_map(&:changed_pwsids).compact.uniq
      changed_layers = import_results.flat_map(&:changed_layers).compact.uniq
      full_refresh = import_results.any?(&:full_refresh_required)

      Rails.logger.info(
        "[ETL] run summary: imported_files=#{imported_files.inspect} " \
        "changed_pwsids=#{changed_pwsids.size} changed_layers=#{changed_layers.inspect} " \
        "full_refresh_required=#{full_refresh} errors=#{errors.size}"
      )
    end

    def build_file_entries
      base_url = ENV.fetch("ETL_SOURCE_URL") { raise "ETL_SOURCE_URL is not set" }.chomp("/")

      file_keys = @only ? [@only] & FILE_IMPORTERS.keys : FILE_IMPORTERS.keys

      file_keys.map do |key|
        ext = FILE_EXTENSIONS[key]
        url = "#{base_url}/#{key}#{ext}"
        {"file_key" => key, "http_path" => url, "last_updated" => last_modified_at(url) || Time.current}
      end
    end
  end
end
