require "rails_helper"

RSpec.describe Etl::HttpFetcher do
  # Build a minimal concrete class so we can call the private method directly.
  let(:fetcher_class) do
    Class.new do
      include Etl::HttpFetcher

      public :fetch_url, :head_url
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

  describe "#head_url" do
    context "with a valid HTTPS URL" do
      let(:url) { "https://s3.example.com/epa_sabs.csv" }
      let(:mock_response) { instance_double(Net::HTTPOK, "[]": nil) }

      before do
        allow(mock_response).to receive(:[]).with("last-modified").and_return("Wed, 15 Jan 2026 10:00:00 GMT")
        allow(Net::HTTP).to receive(:start).and_yield(
          instance_double(Net::HTTP, head: mock_response)
        )
      end

      it "returns the HTTP response" do
        response = fetcher.head_url(url)
        expect(response["last-modified"]).to eq("Wed, 15 Jan 2026 10:00:00 GMT")
      end

      it "uses SSL" do
        fetcher.head_url(url)
        expect(Net::HTTP).to have_received(:start).with("s3.example.com", 443, use_ssl: true)
      end
    end

    context "with a non-HTTPS URL" do
      it "raises InsecureUrlError for http://" do
        expect { fetcher.head_url("http://example.com/data.csv") }
          .to raise_error(Etl::HttpFetcher::InsecureUrlError, /https/i)
      end

      it "raises InsecureUrlError for file://" do
        expect { fetcher.head_url("file:///etc/passwd") }
          .to raise_error(Etl::HttpFetcher::InsecureUrlError)
      end

      it "does not make any HTTP request before raising" do
        allow(Net::HTTP).to receive(:start)
        expect { fetcher.head_url("http://example.com/data.csv") }.to raise_error(Etl::HttpFetcher::InsecureUrlError)
        expect(Net::HTTP).not_to have_received(:start)
      end
    end
  end
end
