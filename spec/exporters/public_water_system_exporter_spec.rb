require "rails_helper"
require "csv"

RSpec.describe PublicWaterSystemExporter do
  let!(:pws) { create(:public_water_system, pws_name: "Test Water Co", stusps: "VT") }
  let(:scope) { PublicWaterSystem.where(pwsid: pws.pwsid) }
  let(:exporter) { described_class.new(scope) }

  describe "#to_csv_stream" do
    subject(:rows) { CSV.parse(exporter.to_csv_stream.to_a.join) }

    it "returns an Enumerator" do
      expect(exporter.to_csv_stream).to be_an(Enumerator)
    end

    it "includes the expected column headers in the first row" do
      expect(rows.first).to include("Utility Name", "Utility ID", "State", "Has open violations", "Grant eligible", "Boil water notices")
    end

    it "includes one data row per system in the scope" do
      create(:public_water_system)
      all_rows = CSV.parse(described_class.new(PublicWaterSystem.all).to_csv_stream.to_a.join)
      expect(all_rows.length).to eq(3) # 1 header + 2 data rows
    end

    it "includes the system name in the data row" do
      expect(rows[1]).to include("Test Water Co")
    end

    it "preserves sort order from the scope" do
      create(:public_water_system, pws_name: "Alpha Water")
      scope = PublicWaterSystem.order(pws_name: :asc)
      result = CSV.parse(described_class.new(scope).to_csv_stream.to_a.join)
      expect(result[1][0]).to eq("Alpha Water")
      expect(result[2][0]).to eq("Test Water Co")
    end

    it "does not raise when associations are nil" do
      expect { exporter.to_csv_stream.to_a }.not_to raise_error
    end

    it "continues fetching across batch boundaries" do
      stub_const("PublicWaterSystemExporter::BATCH_SIZE", 1)
      create(:public_water_system)
      all_rows = CSV.parse(described_class.new(PublicWaterSystem.all).to_csv_stream.to_a.join)
      expect(all_rows.length).to eq(3) # 1 header + 2 data rows
    end

    context "with cols: filter" do
      it "limits headers to pinned columns when cols is an empty array" do
        result = CSV.parse(exporter.to_csv_stream(cols: []).to_a.join)
        expect(result.first).to include("Utility Name")
        expect(result.first).not_to include("State", "Has open violations")
      end

      it "includes only specified columns plus pinned columns" do
        result = CSV.parse(exporter.to_csv_stream(cols: [:stusps, :pwsid]).to_a.join)
        expect(result.first).to include("Utility Name", "Utility ID", "State")
        expect(result.first).not_to include("Has open violations")
      end

      it "exports all columns when cols is nil (default)" do
        result = CSV.parse(exporter.to_csv_stream(cols: nil).to_a.join)
        expect(result.first).to include("Utility Name", "State", "Has open violations", "Boil water notices")
      end

      it "includes data rows with the filtered column set" do
        result = CSV.parse(exporter.to_csv_stream(cols: [:stusps]).to_a.join)
        expect(result.length).to eq(2) # 1 header + 1 data row
        expect(result[1]).to include("VT")
      end

      it "exports correct columns across batch boundaries" do
        stub_const("PublicWaterSystemExporter::BATCH_SIZE", 1)
        create(:public_water_system, stusps: "CA")
        result = CSV.parse(described_class.new(PublicWaterSystem.all).to_csv_stream(cols: [:stusps]).to_a.join)
        expect(result.length).to eq(3) # 1 header + 2 data rows
        expect(result.first).to include("Utility Name", "State")
        expect(result.first).not_to include("Has open violations")
        expect(result[1..]).to all(have_attributes(length: result.first.length))
      end
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
