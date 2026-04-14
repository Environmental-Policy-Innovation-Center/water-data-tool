require "open-uri"

module Etl
  class FileImporter
    EmptyImportError = Class.new(StandardError)
    InsecureUrlError = Class.new(ArgumentError)

    def initialize(file_url:, last_updated:, force: false)
      @file_url = file_url
      @last_updated = last_updated
      @force = force
    end

    def call
      return :skipped unless needs_import?

      content = download
      rows = parse(content)
      validate!(rows)
      import!(rows)
      record_import
      :imported
    end

    private

    def needs_import?
      return true if @force

      last_import = DataImport.where(file_url: @file_url).maximum(:imported_at)
      last_import.nil? || last_import < @last_updated
    end

    def download
      fetch_url(@file_url)
    end

    def fetch_url(url)
      uri = URI.parse(url)
      raise InsecureUrlError, "Only HTTPS URLs are permitted, got: #{uri.scheme}://" unless uri.is_a?(URI::HTTPS)
      uri.open.read
    end

    def validate!(rows)
      raise EmptyImportError, "Import produced 0 rows for #{@file_url}" if rows.empty?
    end

    def record_import
      DataImport.create!(file_url: @file_url, imported_at: Time.current)
    end

    # Subclasses must implement:
    def parse(content) = raise NotImplementedError, "#{self.class}#parse not implemented"
    def import!(rows) = raise NotImplementedError, "#{self.class}#import! not implemented"
  end
end
