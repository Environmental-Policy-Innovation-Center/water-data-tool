require "rails_helper"

RSpec.describe Etl::Importers::NationalBwnHighlevelSummary do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/national_bwn_highlevel_summary.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one row per CSV line" do
      expect(rows.length).to eq(2)
    end

    it "maps date_of_first_advisory to first_advisory_date" do
      expect(rows.first[:first_advisory_date]).to eq("2015-03-12")
    end

    it "casts total_bwn as integer" do
      expect(rows.first[:total_notices]).to eq(3)
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
    end

    it "creates boil_water_summary records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(BoilWaterSummary, :count).by(2)
    end
  end
end
