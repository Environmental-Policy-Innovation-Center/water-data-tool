require "rails_helper"
require "csv"

RSpec.describe PublicWaterSystemExporter do
  let!(:pws) { create(:public_water_system, pws_name: "Test Water Co", stusps: "VT") }
  let(:scope) { PublicWaterSystem.with_details.where(pwsid: pws.pwsid) }
  let(:exporter) { described_class.new(scope) }

  describe "#to_csv" do
    it "returns a string" do
      expect(exporter.to_csv).to be_a(String)
    end

    it "includes the expected column headers in the first row" do
      headers = CSV.parse(exporter.to_csv).first
      expect(headers).to include("Utility Name", "Utility ID", "State", "Has open violations", "Grant eligible", "Boil water notices")
    end

    it "includes one data row per system in the scope" do
      create(:public_water_system)
      scope = PublicWaterSystem.with_details
      rows = CSV.parse(described_class.new(scope).to_csv)
      expect(rows.length).to eq(3) # 1 header + 2 data rows
    end

    it "includes the system name in the data row" do
      rows = CSV.parse(exporter.to_csv)
      expect(rows[1]).to include("Test Water Co")
    end

    it "does not raise when associations are nil" do
      expect { exporter.to_csv }.not_to raise_error
    end
  end

  describe "#to_geojson_stream" do
    # joins all streamed chunks and parses the result
    subject(:geojson) { JSON.parse(exporter.to_geojson_stream.to_a.join) }

    it "returns a FeatureCollection" do
      expect(geojson["type"]).to eq("FeatureCollection")
      expect(geojson["features"]).to be_an(Array)
    end

    it "includes one feature per system in the scope" do
      other = create(:public_water_system)
      scope = PublicWaterSystem.where(pwsid: [pws.pwsid, other.pwsid])
      result = JSON.parse(described_class.new(scope).to_geojson_stream.to_a.join)
      expect(result["features"].length).to eq(2)
    end

    it "continues fetching across batch boundaries" do
      stub_const("PublicWaterSystemExporter::BATCH_SIZE", 1)
      other = create(:public_water_system)
      scope = PublicWaterSystem.where(pwsid: [pws.pwsid, other.pwsid])
      result = JSON.parse(described_class.new(scope).to_geojson_stream.to_a.join)
      expect(result["features"].length).to eq(2)
    end

    it "includes pwsid in feature properties" do
      feature = geojson["features"].first
      expect(feature["properties"]["pwsid"]).to eq(pws.pwsid)
    end

    it "sets geometry to nil when service_area_geometry is not present" do
      feature = geojson["features"].first
      expect(feature["geometry"]).to be_nil
    end

    it "does not raise when associations are nil" do
      expect { exporter.to_geojson_stream.to_a }.not_to raise_error
    end
  end
end
