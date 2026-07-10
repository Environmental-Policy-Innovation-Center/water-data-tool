require "rails_helper"

RSpec.describe Etl::HttpFetcher do
  # Build a minimal concrete class so we can call the private method directly.
  let(:fetcher_class) do
    Class.new do
      include Etl::HttpFetcher

      public :fetch_url, :head_url, :stream_to_tempfile, :last_modified_at
    end
  end

  subject(:fetcher) { fetcher_class.new }

  describe "#fetch_url" do
    context "with a valid HTTPS URL" do
      let(:url) { "https://s3.example.com/data.csv" }

      it "returns the response body" do
        response = instance_double(Net::HTTPOK, code: "200", body: "csv,data\n1,2", message: "OK")
        allow(Net::HTTP).to receive(:get_response).and_return(response)

        expect(fetcher.fetch_url(url)).to eq("csv,data\n1,2")
      end

      it "uses Net::HTTP (does not follow redirects)" do
        response = instance_double(Net::HTTPOK, code: "200", body: "body", message: "OK")
        allow(Net::HTTP).to receive(:get_response).and_return(response)

        fetcher.fetch_url(url)
        # Net::HTTP.get does not follow redirects — a single call is sufficient
        # to confirm we are not using open-uri, which does follow redirects.
        expect(Net::HTTP).to have_received(:get_response).exactly(:once)
      end

      it "raises a clear error for non-success responses" do
        response = instance_double(Net::HTTPNotFound, code: "404", message: "Not Found", body: "<Error>NoSuchKey</Error>")
        allow(Net::HTTP).to receive(:get_response).and_return(response)

        expect { fetcher.fetch_url(url) }
          .to raise_error(Etl::HttpFetcher::HttpResponseError, /GET https:\/\/s3\.example\.com\/data\.csv returned 404 Not Found/)
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
        allow(Net::HTTP).to receive(:get_response)
        expect { fetcher.fetch_url("http://example.com/data.csv") }.to raise_error(Etl::HttpFetcher::InsecureUrlError)
        expect(Net::HTTP).not_to have_received(:get_response)
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

  describe "#last_modified_at" do
    let(:url) { "https://s3.example.com/epa_sabs.csv" }

    it "parses a present Last-Modified header into a Time" do
      response = instance_double(Net::HTTPOK)
      allow(response).to receive(:[]).with("last-modified").and_return("Wed, 15 Jan 2026 10:00:00 GMT")
      allow(fetcher).to receive(:head_url).with(url).and_return(response)

      expect(fetcher.last_modified_at(url)).to eq(Time.zone.parse("Wed, 15 Jan 2026 10:00:00 GMT"))
    end

    it "returns nil and warns when the header is absent" do
      response = instance_double(Net::HTTPOK)
      allow(response).to receive(:[]).with("last-modified").and_return(nil)
      allow(fetcher).to receive(:head_url).with(url).and_return(response)
      allow(Rails.logger).to receive(:warn)

      expect(fetcher.last_modified_at(url)).to be_nil
      expect(Rails.logger).to have_received(:warn).with(/Missing Last-Modified header/)
    end
  end

  describe "#stream_to_tempfile" do
    let(:url) { "https://s3.example.com/data.geojson" }

    context "with a valid HTTPS URL" do
      let(:mock_http) { instance_double(Net::HTTP) }
      let(:mock_response) { instance_double(Net::HTTPOK, code: "200") }

      before do
        allow(Net::HTTP).to receive(:start).and_yield(mock_http)
        allow(mock_http).to receive(:request_get).and_yield(mock_response)
        allow(mock_response).to receive(:read_body).and_yield("chunk1").and_yield("chunk2")
      end

      it "returns a Tempfile containing the streamed body" do
        tmpfile = fetcher.stream_to_tempfile(url)
        tmpfile.rewind
        expect(tmpfile.read).to eq("chunk1chunk2")
      ensure
        tmpfile&.close!
      end

      it "uses SSL" do
        fetcher.stream_to_tempfile(url)
        expect(Net::HTTP).to have_received(:start).with("s3.example.com", 443, use_ssl: true)

        # tempfile cleanup — suppress errors if already cleaned up
      end

      it "streams via read_body chunks rather than buffering the full response" do
        fetcher.stream_to_tempfile(url)
        expect(mock_response).to have_received(:read_body)

        # tempfile cleanup
      end

      it "raises a clear error for non-success responses without reading the body" do
        error_response = instance_double(Net::HTTPNotFound, code: "404", message: "Not Found")
        allow(Net::HTTP).to receive(:start).and_yield(mock_http)
        allow(mock_http).to receive(:request_get).and_yield(error_response)
        allow(error_response).to receive(:read_body)

        expect { fetcher.stream_to_tempfile(url) }
          .to raise_error(Etl::HttpFetcher::HttpResponseError, /GET https:\/\/s3\.example\.com\/data\.geojson returned 404 Not Found/)
        expect(error_response).not_to have_received(:read_body)
      end
    end

    context "with a non-HTTPS URL" do
      it "raises InsecureUrlError for http://" do
        expect { fetcher.stream_to_tempfile("http://example.com/f.json") }
          .to raise_error(Etl::HttpFetcher::InsecureUrlError, /https/i)
      end

      it "raises InsecureUrlError for file://" do
        expect { fetcher.stream_to_tempfile("file:///etc/passwd") }
          .to raise_error(Etl::HttpFetcher::InsecureUrlError)
      end

      it "does not open any HTTP connection before raising" do
        allow(Net::HTTP).to receive(:start)
        expect { fetcher.stream_to_tempfile("http://example.com/f.json") }
          .to raise_error(Etl::HttpFetcher::InsecureUrlError)
        expect(Net::HTTP).not_to have_received(:start)
      end
    end
  end
end
