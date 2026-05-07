module Etl
  # Orchestrates a full ETL run: check S3 Last-Modified headers, dispatch each
  # source file to its importer, and run post-import steps when geometry data
  # was refreshed.
  class Importer
    include Etl::HttpFetcher

    # Backward-compatible alias — existing code and specs reference this constant.
    InsecureUrlError = Etl::HttpFetcher::InsecureUrlError

    # Maps the filename stem to the importer class.
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

    FILE_EXTENSIONS = {
      "epa_sabs" => ".csv",
      "epa_sabs_geoms" => ".geojson",
      "sdwis_viols" => ".csv",
      "epa_sabs_xwalk" => ".csv",
      "xwalk_pct_change_10yr" => ".csv",
      "cejst" => ".csv",
      "ejscreen" => ".csv",
      "svi" => ".csv",
      "cvi" => ".csv",
      "national_bwn_highlevel_summary" => ".csv",
      "pwsid_funded_highlevel_summary" => ".csv",
      "pwsid_npdes_usts_rmps_imp" => ".csv"
    }.freeze

    def initialize(force: false, only: nil)
      @force = force
      @only = only
    end

    def call
      entries = build_file_entries
      new_imports = entries.select { |entry| @force || entry['last_updated'] > Etl::ImportLog.last_import_time(entry['file_key']) }
      errors = []

      entries.each do |entry|
        file_key = entry["file_key"]
        next if @only && file_key != @only

        klass = FILE_IMPORTERS[file_key]

        begin
          klass.new(file_url: entry["http_path"], last_updated: entry["last_updated"], force: @force).call
       rescue => e # StandardError only — intentional fault isolation per importer
         errors << { file_key: file_key, error: e }
         Rails.logger.error("[ETL] #{file_key} failed: #{e.class} — #{e.message}")
        end
      end

      # Run post-import steps with passed files to allow conditional logic
      Etl::PostImportSteps.call(new_imports)

      errors
    end

    private

    def build_file_entries
      base_url = ENV.fetch("ETL_SOURCE_URL") { raise "ETL_SOURCE_URL is not set" }.chomp("/")

      FILE_IMPORTERS.keys.map do |key|
        ext = FILE_EXTENSIONS[key]
        url = "#{base_url}/#{key}#{ext}"
        response = head_url(url)
        last_modified = response["last-modified"]
        raise "Missing Last-Modified header for #{url}" if last_modified.nil?
        {"file_key" => key, "http_path" => url, "last_updated" => Time.zone.parse(last_modified)}
      end
    end
  end
end
