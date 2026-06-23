module Etl
  # Orchestrates a full ETL run: check S3 Last-Modified headers, dispatch each
  # source file to its importer, and run post-import steps when geometry data
  # was refreshed.
  class Importer
    include Etl::HttpFetcher

    # Backward-compatible alias — existing code and specs reference this constant.
    InsecureUrlError = Etl::HttpFetcher::InsecureUrlError

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
      "pwsid_funded_highlevel_summary" => Etl::Importers::Generic
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
      "pwsid_funded_highlevel_summary" => ".csv"
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

      Etl::PostImportSteps.call(import_results: import_results)

      errors
    end

    private

    def normalize_result(file_key, result)
      return result if result.is_a?(Etl::ImportResult)

      if result == :imported
        Etl::ImportResult.imported(file_key: file_key, full_refresh_required: true)
      elsif result == :skipped || result.nil?
        Etl::ImportResult.skipped(file_key: file_key)
      else
        Etl::ImportResult.imported(file_key: file_key, full_refresh_required: true)
      end
    end

    def build_file_entries
      base_url = ENV.fetch("ETL_SOURCE_URL") { raise "ETL_SOURCE_URL is not set" }.chomp("/")

      file_keys = @only ? [@only] : FILE_IMPORTERS.keys

      file_keys.map do |key|
        ext = FILE_EXTENSIONS[key]
        url = "#{base_url}/#{key}#{ext}"
        response = head_url(url)
        last_modified = response["last-modified"]
        Rails.logger.warn("[ETL] Missing Last-Modified header for #{url}; importing as changed") if last_modified.nil?

        {"file_key" => key, "http_path" => url, "last_updated" => last_modified ? Time.zone.parse(last_modified) : Time.current}
      end
    end
  end
end
