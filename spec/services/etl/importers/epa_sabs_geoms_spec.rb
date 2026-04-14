require "rails_helper"

RSpec.describe Etl::Importers::EpaSabsGeoms do
  let(:geojson_content) { File.read(Rails.root.join("spec/fixtures/etl/epa_sabs_geoms.geojson")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.geojson", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(geojson_content) }

    it "returns one row per GeoJSON feature" do
      expect(rows.length).to eq(1)
    end

    it "extracts pwsid from feature properties" do
      expect(rows.first[:pwsid]).to eq("VT0000001")
    end

    it "stores raw GeoJSON geometry string for SQL import" do
      expect(rows.first[:geom_json]).to be_a(String)
      parsed = JSON.parse(rows.first[:geom_json])
      expect(parsed["type"]).to eq("MultiPolygon")
    end
  end

  describe "#import!" do
    before { create(:public_water_system, pwsid: "VT0000001") }

    it "inserts service_area_geometry records via PostGIS" do
      rows = importer.parse(geojson_content)
      expect { importer.import!(rows) }.to change(ServiceAreaGeometry, :count).by(1)
    end

    it "persists a valid geometry" do
      rows = importer.parse(geojson_content)
      importer.import!(rows)
      sag = ServiceAreaGeometry.find_by(pwsid: "VT0000001")
      expect(sag).not_to be_nil
      expect(sag.geom).not_to be_nil
    end
  end
end
