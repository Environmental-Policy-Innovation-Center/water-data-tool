require "rails_helper"

RSpec.describe Etl::Importers::EpaSabsGeoms do
  let(:fixture_path) { Rails.root.join("spec/fixtures/etl/epa_sabs_geoms.geojson") }
  let(:file_url) { "https://s3.example.com/epa_sabs_geoms.geojson" }
  let(:importer) { described_class.new(file_url: file_url, last_updated: 1.day.ago) }

  before do
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:flush)
  end

  # Stubs stream_to_tempfile to return a real Tempfile backed by the fixture,
  # avoiding any network call.
  def stub_download(path = fixture_path)
    tmpfile = Tempfile.new(["epa_sabs_geoms", ".geojson"])
    tmpfile.write(File.read(path))
    tmpfile.rewind
    allow(importer).to receive(:stream_to_tempfile).and_return(tmpfile)
    tmpfile
  end

  describe "#call" do
    context "when no prior import exists" do
      before do
        create(:public_water_system, pwsid: "VT0000001")
        stub_download
      end

      it "inserts service_area_geometry records via PostGIS" do
        expect { importer.call }.to change(ServiceAreaGeometry, :count).by(1)
      end

      it "persists a valid geometry" do
        importer.call
        sag = ServiceAreaGeometry.find_by(pwsid: "VT0000001")
        expect(sag).not_to be_nil
        expect(sag.geom).not_to be_nil
      end

      it "returns an imported ImportResult" do
        expect(importer.call).to have_attributes(status: :imported, file_key: "epa_sabs_geoms")
      end

      it "returns changed geometry metadata" do
        result = importer.call

        expect(result.status).to eq(:imported)
        expect(result.changed_pwsids).to eq(["VT0000001"])
        expect(result.changed_layers).to eq(%w[pws places])
        expect(result.geometry_changed).to be(true)
      end

      it "records a DataImport entry" do
        expect { importer.call }.to change(DataImport, :count).by(1)
      end

      it "stores the correct file_url on the DataImport record" do
        importer.call
        expect(DataImport.last.file_url).to eq(file_url)
      end
    end

    context "when the file is unchanged since last import" do
      before { create(:data_import, file_url: file_url, imported_at: 1.hour.ago) }

      let(:importer) { described_class.new(file_url: file_url, last_updated: 2.hours.ago) }

      it "returns a skipped ImportResult without downloading" do
        expect(importer).not_to receive(:stream_to_tempfile)
        expect(importer.call).to have_attributes(status: :skipped, file_key: "epa_sabs_geoms")
      end

      it "does not create a new DataImport record" do
        expect { importer.call }.not_to change(DataImport, :count)
      end
    end

    context "when the GeoJSON has no features" do
      it "raises EmptyImportError and does not record a DataImport" do
        tmpfile = Tempfile.new(["empty", ".geojson"])
        tmpfile.write('{"type":"FeatureCollection","features":[]}')
        tmpfile.rewind
        allow(importer).to receive(:stream_to_tempfile).and_return(tmpfile)

        expect { importer.call }.to raise_error(Etl::FileImporter::EmptyImportError)
        expect(DataImport.count).to eq(0)
      end
    end

    context "when a streamed batch import returns an invalid result" do
      before do
        create(:public_water_system, pwsid: "VT0000001")
        stub_download
        allow(importer).to receive(:import!).and_return(:imported)
      end

      it "raises InvalidImportResultError and does not record a DataImport" do
        expect { importer.call }
          .to raise_error(Etl::FileImporter::InvalidImportResultError, /EpaSabsGeoms#import!/)
        expect(DataImport.count).to eq(0)
      end
    end

    context "with force: true" do
      before do
        create(:public_water_system, pwsid: "VT0000001")
        create(:data_import, file_url: file_url, imported_at: 1.hour.ago)
        stub_download
      end

      let(:importer) { described_class.new(file_url: file_url, last_updated: 2.hours.ago, force: true) }

      it "imports even when the file has not changed" do
        expect { importer.call }.to change(ServiceAreaGeometry, :count).by(1)
      end
    end
  end

  describe "FeatureHandler" do
    let(:handler_class) { Etl::Importers::EpaSabsGeoms::FeatureHandler }

    it "yields one hash per GeoJSON feature" do
      features = []
      handler = handler_class.new { |f| features << f }
      Oj.saj_parse(handler, File.read(fixture_path))

      expect(features.length).to eq(1)
    end

    it "extracts pwsid from feature properties" do
      features = []
      handler = handler_class.new { |f| features << f }
      Oj.saj_parse(handler, File.read(fixture_path))

      expect(features.first.dig("properties", "pwsid")).to eq("VT0000001")
    end

    it "includes geometry as a parseable hash" do
      features = []
      handler = handler_class.new { |f| features << f }
      Oj.saj_parse(handler, File.read(fixture_path))

      geom = features.first["geometry"]
      expect(geom["type"]).to eq("MultiPolygon")
      expect(geom["coordinates"]).to be_an(Array)
    end
  end

  describe "#import!" do
    let(:row) do
      features = []
      handler = Etl::Importers::EpaSabsGeoms::FeatureHandler.new { |feature| features << feature }
      Oj.saj_parse(handler, File.read(fixture_path))
      {
        pwsid: features.first.dig("properties", "pwsid"),
        geom_json: Oj.dump(features.first["geometry"])
      }
    end

    before { create(:public_water_system, pwsid: "VT0000001") }

    it "stores a geometry digest" do
      importer.import!([row])

      expect(ServiceAreaGeometry.find_by!(pwsid: "VT0000001").geom_digest).to be_present
    end

    it "skips unchanged geometries and returns no changed pwsids" do
      importer.import!([row])

      result = importer.import!([row])

      expect(result.changed_pwsids).to be_empty
      expect(result.geometry_changed).to be(false)
    end

    it "returns previous geometry bounds when an existing geometry changes" do
      importer.import!([row])
      changed_row = row.merge(
        geom_json: Oj.dump({
          "type" => "MultiPolygon",
          "coordinates" => [[[[-73.0, 44.0], [-72.9, 44.0], [-72.9, 44.1], [-73.0, 44.1], [-73.0, 44.0]]]]
        })
      )

      result = importer.import!([changed_row])

      expect(result.previous_geometry_bboxes).to contain_exactly(
        satisfy { |bbox|
          west, south, east, north = bbox
          west < east && south < north && !west.in?(-73.01..-72.99)
        }
      )
    end
  end
end
