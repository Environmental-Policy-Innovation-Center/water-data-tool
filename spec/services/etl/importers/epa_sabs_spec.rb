require "rails_helper"

RSpec.describe Etl::Importers::EpaSabs do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/epa_sabs.csv")) }

  describe "#parse" do
    subject(:rows) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago).parse(csv_content) }

    it "returns one row per CSV line" do
      expect(rows.length).to eq(2)
    end

    it "maps pwsid" do
      expect(rows.first[:pwsid]).to eq("VT0000001")
    end

    it "casts population_served_count as integer" do
      expect(rows.first[:population_served_count]).to eq(1500)
    end

    it "casts area_sq_miles as decimal" do
      expect(rows.first[:area_sq_miles]).to eq(BigDecimal("12.5"))
    end

    it "maps epic_area_mi2 to area_sq_miles" do
      expect(rows.first).to have_key(:area_sq_miles)
    end

    it "returns nil for NA area values" do
      expect(rows.last[:area_sq_miles]).to be_nil
    end

    it "derives stusps from the first two characters of pwsid" do
      expect(rows.first[:stusps]).to eq("VT")
    end

    it "includes timestamps" do
      expect(rows.first).to have_key(:created_at)
      expect(rows.first).to have_key(:updated_at)
    end
  end

  describe "#import!" do
    let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

    it "upserts rows into public_water_systems" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(PublicWaterSystem, :count).by(2)
    end

    it "updates existing records on conflict" do
      create(:public_water_system, pwsid: "VT0000001", pws_name: "Old Name")
      rows = importer.parse(csv_content)
      importer.import!(rows)
      expect(PublicWaterSystem.find("VT0000001").pws_name).to eq("Green Mountain Water")
    end
  end
end
