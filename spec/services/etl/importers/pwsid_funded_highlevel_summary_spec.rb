require "rails_helper"

RSpec.describe Etl::Importers::PwsidFundedHighlevelSummary do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/pwsid_funded_highlevel_summary.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one row per CSV line" do
      expect(rows.length).to eq(2)
    end

    it "casts times_funded as integer" do
      expect(rows.first[:times_funded]).to eq(2)
    end

    it "casts total_srf_assistance as decimal" do
      expect(rows.first[:total_srf_assistance]).to eq(BigDecimal("850000.00"))
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
    end

    it "creates funding_summary records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(FundingSummary, :count).by(2)
    end

    it "returns an import result without tile refresh layers" do
      rows = importer.parse(csv_content)
      result = importer.import!(rows)

      expect(result).to eq(
        Etl::ImportResult.imported(file_key: "f", changed_layers: [])
      )
    end
  end
end
