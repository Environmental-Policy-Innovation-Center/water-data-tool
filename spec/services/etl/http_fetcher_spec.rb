require "rails_helper"

RSpec.describe Etl::HttpFetcher do
  # Build a minimal concrete class so we can call the private method directly.
  let(:fetcher_class) do
    Class.new do
      include Etl::HttpFetcher

      public :fetch_url
    end
  end

  subject(:fetcher) { fetcher_class.new }

  describe "#fetch_url" do
    context "with a valid HTTPS URL" do
      let(:url) { "https://s3.example.com/data.csv" }

      it "returns the response body" do
        allow(Net::HTTP).to receive(:get).and_return("csv,data\n1,2")
        expect(fetcher.fetch_url(url)).to eq("csv,data\n1,2")
      end

      it "uses Net::HTTP (does not follow redirects)" do
        allow(Net::HTTP).to receive(:get).and_return("body")
        fetcher.fetch_url(url)
        # Net::HTTP.get does not follow redirects — a single call is sufficient
        # to confirm we are not using open-uri, which does follow redirects.
        expect(Net::HTTP).to have_received(:get).exactly(:once)
      end
    end

    context "with a non-HTTPS URL" do
      it "raises InsecureUrlError for http://" do
        expect { fetcher.fetch_url("http://example.com/data.csv") }
          .to raise_error(Etl::HttpFetcher::InsecureUrlError, /https/i)
      end

      it "raises InsecureUrlError for file://" do
        expect { fetcher.fetch_url("file:///etc/passwd") }
          .to raise_error(Etl::HttpFetcher::InsecureUrlError)
      end

      it "raises InsecureUrlError for ftp://" do
        expect { fetcher.fetch_url("ftp://example.com/data.csv") }
          .to raise_error(Etl::HttpFetcher::InsecureUrlError)
      end

      it "does not make any HTTP request before raising" do
        allow(Net::HTTP).to receive(:get)
        expect { fetcher.fetch_url("http://example.com/data.csv") }.to raise_error(Etl::HttpFetcher::InsecureUrlError)
        expect(Net::HTTP).not_to have_received(:get)
      end
    end
  end
end
