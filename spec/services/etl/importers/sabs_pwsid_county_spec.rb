require "rails_helper"

RSpec.describe Etl::Importers::SabsPwsidCounty do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/sabs_pwsid_county.csv")) }
  let(:importer) { described_class.new(file_url: "https://example.com/sabs_pwsid_county.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one row per unique pwsid" do
      expect(rows.length).to eq(4)
    end

    it "maps a single-county row directly" do
      row = rows.find { |r| r[:pwsid] == "VT0000001" }
      expect(row[:counties]).to eq("Chittenden County, VT")
    end

    it "preserves semicolon-separated counties from a single row" do
      row = rows.find { |r| r[:pwsid] == "VT0000002" }
      expect(row[:counties]).to eq("Chittenden County, VT; Franklin County, VT")
    end

    it "aggregates multiple rows for the same pwsid" do
      row = rows.find { |r| r[:pwsid] == "VT0000003" }
      expect(row[:counties]).to eq("Addison County, VT; Washington County, VT")
    end

    it "deduplicates county values for the same pwsid" do
      row = rows.find { |r| r[:pwsid] == "VT0000004" }
      expect(row[:counties]).to eq("Rutland County, VT")
    end

    it "sorts counties alphabetically" do
      row = rows.find { |r| r[:pwsid] == "VT0000002" }
      counties = row[:counties].split("; ")
      expect(counties).to eq(counties.sort)
    end

    it "skips rows with a blank county_served without raising" do
      expect { rows }.not_to raise_error
      expect(rows.find { |r| r[:pwsid] == "VT0000005" }).to be_nil
    end
  end

  describe "#import!" do
    let!(:pws1) { create(:public_water_system, pwsid: "VT0000001", counties: nil) }
    let!(:pws2) { create(:public_water_system, pwsid: "VT0000002", counties: nil) }

    let(:rows) do
      [
        {pwsid: "VT0000001", counties: "Chittenden County, VT"},
        {pwsid: "VT0000002", counties: "Chittenden County, VT; Franklin County, VT"},
        {pwsid: "UNKNOWN999", counties: "Nowhere County, XX"}
      ]
    end

    before { importer.import!(rows) }

    it "updates the counties column on existing records" do
      expect(pws1.reload.counties).to eq("Chittenden County, VT")
      expect(pws2.reload.counties).to eq("Chittenden County, VT; Franklin County, VT")
    end

    it "does not create new records for unknown pwsids" do
      expect(PublicWaterSystem.find_by(pwsid: "UNKNOWN999")).to be_nil
    end

    it "returns an import result without tile refresh layers" do
      result = importer.import!(rows)

      expect(result).to eq(
        Etl::ImportResult.imported(file_key: "sabs_pwsid_county", changed_layers: [])
      )
    end

    context "when a pwsid has only blank county_served rows in the CSV" do
      let!(:pws_with_existing_counties) { create(:public_water_system, pwsid: "VT0000006", counties: "Existing County, VT") }

      before { importer.import!([]) }

      it "preserves the existing county data rather than clearing it" do
        expect(pws_with_existing_counties.reload.counties).to eq("Existing County, VT")
      end
    end
  end
end
