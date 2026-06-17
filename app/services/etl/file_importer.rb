module Etl
  class FileImporter
    include Etl::HttpFetcher

    EmptyImportError = Class.new(StandardError)

    # Backward-compatible alias — existing code and specs reference this constant.
    InsecureUrlError = Etl::HttpFetcher::InsecureUrlError
    LEGACY_IMPORT_STATUSES = [:imported, :skipped].freeze

    def initialize(file_url:, last_updated:, force: false)
      @file_url = file_url
      @last_updated = last_updated
      @force = force
    end

    def call
      filename = @file_url.split("/").last

      unless needs_import?
        log("[ETL] #{filename}: skipped (unchanged since last import)")
        return Etl::ImportResult.skipped(file_key: file_key)
      end

      log("[ETL] #{filename}: downloading...")
      started_at = Time.current
      content = download
      elapsed = (Time.current - started_at).round(1)
      size_mb = (content.bytesize / 1_048_576.0).round(1)
      log("[ETL] #{filename}: downloaded #{size_mb} MB in #{elapsed}s")

      rows = parse(content)
      validate!(rows)
      result = import!(rows)
      record_import
      log("[ETL] #{filename}: import complete")
      return result if import_result?(result)

      Etl::ImportResult.imported(file_key: file_key, full_refresh_required: true)
    end

    private

    def import_result?(result)
      result.is_a?(Etl::ImportResult) || LEGACY_IMPORT_STATUSES.include?(result)
    end

    def needs_import?
      return true if @force

      last_import = DataImport.where(file_url: @file_url).maximum(:imported_at)
      last_import.nil? || last_import < @last_updated
    end

    def download
      fetch_url(@file_url)
    end

    # Validates that parse returned a non-empty result.
    #
    # Contract: subclasses that return a non-Array from +parse+ (e.g. a Hash
    # of sub-collections) MUST override this method and call +empty?+ on each
    # relevant sub-collection themselves.
    def validate!(rows)
      raise EmptyImportError, "Import produced 0 rows for #{@file_url}" if rows.empty?
    end

    def record_import
      DataImport.create!(file_url: @file_url, imported_at: Time.current)
    end

    def log(msg)
      Rails.logger.info(msg)
      $stdout.puts msg
      $stdout.flush
    end

    def file_key
      File.basename(@file_url, ".*")
    end

    # Subclasses must implement:
    def parse(content) = raise NotImplementedError, "#{self.class}#parse not implemented"
    def import!(rows) = raise NotImplementedError, "#{self.class}#import! not implemented"
  end
end
