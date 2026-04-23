require "net/http"

module Etl
  # Shared HTTPS-only fetcher included by Etl::Importer and Etl::FileImporter.
  #
  # Uses Net::HTTP rather than open-uri. Net::HTTP does NOT follow redirects,
  # which prevents a crafted server redirect (e.g. from HTTPS → file://) from
  # bypassing the HTTPS-only guard that open-uri would silently follow.
  module HttpFetcher
    InsecureUrlError = Class.new(ArgumentError)

    private

    def fetch_url(url)
      uri = validated_https_uri(url)
      Net::HTTP.get(uri)
    end

    def head_url(url)
      uri = validated_https_uri(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.head(uri.request_uri)
      end
    end

    def validated_https_uri(url)
      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTPS)
        raise InsecureUrlError, "Only HTTPS URLs are permitted, got: #{uri.scheme}://"
      end
      uri
    end
  end
end
