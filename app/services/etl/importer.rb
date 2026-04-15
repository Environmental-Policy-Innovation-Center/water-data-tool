module Etl
  # Orchestrates a full ETL run: fetch the S3 manifest, diff timestamps,
  # dispatch each source file to its importer, and run post-import steps
  # when geometry data was refreshed.
  class Importer
    include Etl::HttpFetcher

    # Backward-compatible alias — existing code and specs reference this constant.
    InsecureUrlError = Etl::HttpFetcher::InsecureUrlError

    # Maps the filename stem from the S3 manifest to the importer class.
    FILE_IMPORTERS = {
      "epa_sabs" => Etl::Importers::EpaSabs,
      "epa_sabs_geoms" => Etl::Importers::EpaSabsGeoms,
      "sdwis_viols" => Etl::Importers::SdwisViols,
      "epa_sabs_xwalk" => Etl::Importers::EpaSabsXwalk,
      "xwalk_pct_change_10yr" => Etl::Importers::XwalkPctChange10yr,
      "cejst" => Etl::Importers::Cejst,
      "ejscreen" => Etl::Importers::Ejscreen,
      "svi" => Etl::Importers::Svi,
      "cvi" => Etl::Importers::Cvi,
      "national_bwn_highlevel_summary" => Etl::Importers::NationalBwnHighlevelSummary,
      "pwsid_funded_highlevel_summary" => Etl::Importers::PwsidFundedHighlevelSummary,
      "pwsid_npdes_usts_rmps_imp" => Etl::Importers::PwsidNpdesUstsRmpsImp
    }.freeze

    def initialize(manifest_url:, force: false, only: nil)
      @manifest_url = manifest_url
      @force = force
      @only = only
    end

    def call
      manifest = fetch_manifest
      geometry_imported = false
      any_imported = false
      errors = []

      manifest.each do |entry|
        file_key = extract_file_key(entry["http_path"])
        next unless FILE_IMPORTERS.key?(file_key)
        next if @only && file_key != @only

        klass = FILE_IMPORTERS[file_key]
        last_updated = Time.zone.parse(entry["last_updated"])

        begin
          result = klass.new(file_url: entry["http_path"], last_updated: last_updated, force: @force).call
          if result == :imported
            any_imported = true
            geometry_imported = true if file_key == "epa_sabs_geoms"
          end
        rescue => e # StandardError only — intentional fault isolation per importer
          errors << {file_key: file_key, error: e}
          Rails.logger.error("[ETL] #{file_key} failed: #{e.class} — #{e.message}")
        end
      end

      # Bust stale tiles before spatial reprocessing so requests during
      # the reindex window generate fresh tiles on demand.
      Etl::PostImportSteps.bust_tile_cache if any_imported
      Etl::PostImportSteps.call if geometry_imported
      TileCacheWarmJob.perform_later if any_imported

      errors
    end

    private

    def fetch_manifest
      JSON.parse(fetch_url(@manifest_url))
    end

    # Derive the file key from the filename stem of the URL path.
    # e.g. "https://s3.example.com/dir/epa_sabs.csv" → "epa_sabs"
    def extract_file_key(http_path)
      File.basename(URI.parse(http_path).path, ".*")
    end
  end
end
