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
      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTPS)
        raise InsecureUrlError, "Only HTTPS URLs are permitted, got: #{uri.scheme}://"
      end
      Net::HTTP.get(uri)
    end
  end
end
