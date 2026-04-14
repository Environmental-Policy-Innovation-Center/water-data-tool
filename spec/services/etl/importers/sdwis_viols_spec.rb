require "rails_helper"

RSpec.describe Etl::Importers::SdwisViols do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/sdwis_viols.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one pws_row and one viol_row per CSV line" do
      expect(rows[:pws_rows].length).to eq(2)
      expect(rows[:viol_rows].length).to eq(2)
    end

    it "casts boolean indicators on pws_rows" do
      expect(rows[:pws_rows].first[:is_grant_eligible]).to be(true)
      expect(rows[:pws_rows].first[:is_wholesaler]).to be(false)
    end

    it "casts violation counts as integers" do
      expect(rows[:viol_rows].first[:health_violations_5yr]).to eq(2)
      expect(rows[:viol_rows].first[:total_violations_10yr]).to eq(6)
    end

    it "maps legacy column names to new schema names" do
      viol = rows[:viol_rows].first
      expect(viol).to have_key(:groundwater_rule_5yr)
      expect(viol).to have_key(:surface_water_treatment_5yr)
      expect(viol).to have_key(:lead_and_copper_5yr)
    end
  end

  describe "#import!" do
    before { create(:public_water_system, pwsid: "VT0000001") }
    before { create(:public_water_system, pwsid: "VT0000002") }

    it "upserts pws attribute columns and creates violations_summaries" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(ViolationsSummary, :count).by(2)
    end

    it "sets boolean fields on PublicWaterSystem" do
      rows = importer.parse(csv_content)
      importer.import!(rows)
      pws = PublicWaterSystem.find("VT0000001")
      expect(pws.is_grant_eligible).to be(true)
      expect(pws.is_wholesaler).to be(false)
    end
  end
end
