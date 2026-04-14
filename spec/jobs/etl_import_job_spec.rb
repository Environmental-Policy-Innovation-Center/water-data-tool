require "rails_helper"

RSpec.describe EtlImportJob, type: :job do
  describe "#perform" do
    let(:manifest_url) { "https://s3.example.com/data.json" }

    before do
      allow(ENV).to receive(:fetch).with("ETL_MANIFEST_URL").and_return(manifest_url)
    end

    it "instantiates Etl::Importer with the manifest URL and calls it" do
      importer = instance_double(Etl::Importer, call: [])
      expect(Etl::Importer).to receive(:new).with(manifest_url: manifest_url, force: false, only: nil).and_return(importer)
      described_class.new.perform
    end

    it "passes force: true when invoked with force argument" do
      importer = instance_double(Etl::Importer, call: [])
      expect(Etl::Importer).to receive(:new).with(hash_including(force: true)).and_return(importer)
      described_class.new.perform(force: true)
    end

    it "passes only: 'epa_sabs' when invoked with only argument" do
      importer = instance_double(Etl::Importer, call: [])
      expect(Etl::Importer).to receive(:new).with(hash_including(only: "epa_sabs")).and_return(importer)
      described_class.new.perform(only: "epa_sabs")
    end

    it "does not raise when all files succeed" do
      importer = instance_double(Etl::Importer, call: [])
      allow(Etl::Importer).to receive(:new).and_return(importer)
      expect { described_class.new.perform }.not_to raise_error
    end

    context "when the importer returns errors" do
      let(:failure) { {file_key: "epa_sabs", error: StandardError.new("network timeout")} }

      before do
        importer = instance_double(Etl::Importer, call: [failure])
        allow(Etl::Importer).to receive(:new).and_return(importer)
      end

      it "raises so SolidQueue records the job as failed" do
        expect { described_class.new.perform }.to raise_error(RuntimeError)
      end

      it "includes the failure count and details in the error message" do
        expect { described_class.new.perform }
          .to raise_error(RuntimeError, /1 failure.*epa_sabs.*network timeout/m)
      end
    end

    context "when ETL_MANIFEST_URL is not configured" do
      before do
        # Simulate a missing env var by invoking the fetch block.
        allow(ENV).to receive(:fetch).with("ETL_MANIFEST_URL") { |_key, &block| block.call }
      end

      it "raises with a descriptive message" do
        expect { described_class.new.perform }
          .to raise_error(RuntimeError, "ETL_MANIFEST_URL is not configured")
      end
    end
  end
end
