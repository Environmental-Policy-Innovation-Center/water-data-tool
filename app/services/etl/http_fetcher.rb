require "net/http"

module Etl
  # Shared HTTPS-only fetcher included by Etl::Importer and Etl::FileImporter.
  #
  # Uses Net::HTTP rather than open-uri. Net::HTTP does NOT follow redirects,
  # which prevents a crafted server redirect (e.g. from HTTPS → file://) from
  # bypassing the HTTPS-only guard that open-uri would silently follow.
  module HttpFetcher
    InsecureUrlError = Class.new(ArgumentError)
    HttpResponseError = Class.new(StandardError)

    private

    def fetch_url(url)
      uri = validated_https_uri(url)
      response = Net::HTTP.get_response(uri)
      ensure_success!(response, uri, method: "GET")
      response.body
    end

    # Streams the HTTPS response body to a Tempfile in chunks, never buffering
    # the full response in memory. Returns the open, rewound Tempfile — caller
    # is responsible for calling close! when done.
    def stream_to_tempfile(url)
      uri = validated_https_uri(url)
      ext = File.extname(uri.path)
      tmpfile = Tempfile.new(["etl_download", ext], binmode: true)

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request_get(uri.request_uri) do |response|
          ensure_success!(response, uri, method: "GET")
          response.read_body { |chunk| tmpfile.write(chunk) }
        end
      end

      tmpfile.rewind
      tmpfile
    rescue
      tmpfile&.close!
      raise
    end

    def head_url(url)
      uri = validated_https_uri(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.head(uri.request_uri)
      end
    end

    def last_modified_at(url)
      value = head_url(url)["last-modified"]
      return Time.zone.parse(value) if value

      Rails.logger.warn("[ETL] Missing Last-Modified header for #{url}; treating as changed")
      nil
    end

    def validated_https_uri(url)
      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTPS)
        raise InsecureUrlError, "Only HTTPS URLs are permitted, got: #{uri.scheme}://"
      end
      uri
    end

    def ensure_success!(response, uri, method:)
      return if response.code.to_i.between?(200, 299)

      raise HttpResponseError, "#{method} #{uri} returned #{response.code} #{response.message}"
    end
  end
end
