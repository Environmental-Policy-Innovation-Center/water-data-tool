require "rails_helper"

RSpec.describe EtlImportJob, type: :job do
  describe "#perform" do
    let(:manifest_url) { "https://s3.example.com/data.json" }

    before do
      allow(ENV).to receive(:fetch).with("ETL_MANIFEST_URL").and_return(manifest_url)
    end

    it "instantiates Etl::Importer with the manifest URL and calls it" do
      importer = instance_double(Etl::Importer, call: nil)
      expect(Etl::Importer).to receive(:new).with(manifest_url: manifest_url, force: false, only: nil).and_return(importer)
      described_class.new.perform
    end

    it "passes force: true when invoked with force argument" do
      importer = instance_double(Etl::Importer, call: nil)
      expect(Etl::Importer).to receive(:new).with(hash_including(force: true)).and_return(importer)
      described_class.new.perform(force: true)
    end

    it "passes only: 'epa_sabs' when invoked with only argument" do
      importer = instance_double(Etl::Importer, call: nil)
      expect(Etl::Importer).to receive(:new).with(hash_including(only: "epa_sabs")).and_return(importer)
      described_class.new.perform(only: "epa_sabs")
    end
  end
end
