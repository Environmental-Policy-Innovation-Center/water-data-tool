require "rails_helper"

RSpec.describe CartographicBoundaries do
  let(:tmp_dir) { Rails.root.join("tmp/cartographic") }
  let(:instance) { described_class.new }

  before do
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:write)
    allow($stderr).to receive(:write)
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe ".load" do
    it "delegates to a new instance" do
      expect_any_instance_of(described_class).to receive(:load)
      described_class.load
    end
  end

  describe ".loaded?" do
    it "returns false when any of the three boundary tables is empty" do
      expect(described_class.loaded?).to be false
    end

    it "returns true when all three boundary tables have rows" do
      allow(CartographicState).to receive(:exists?).and_return(true)
      allow(CartographicCounty).to receive(:exists?).and_return(true)
      allow(CartographicPlace).to receive(:exists?).and_return(true)

      expect(described_class.loaded?).to be true
    end
  end

  describe "#load" do
    around do |example|
      original = ENV["ETL_SOURCE_URL"]
      ENV["ETL_SOURCE_URL"] = "https://tech-team-data.s3.amazonaws.com/national-dw-tool/staging"
      example.run
    ensure
      ENV["ETL_SOURCE_URL"] = original
    end

    it "builds cartographic boundary zip URLs from the ETL source URL" do
      expect(described_class::LAYERS.map { |layer| layer[:zip_file] }).to eq([
        "us_state_500k.zip",
        "us_county_500k.zip",
        "us_place_500k.zip"
      ])
      expect(described_class::LAYERS.map { |layer| layer[:shapefile] }).to eq([
        "us_state_500k.shp",
        "us_county_500k.shp",
        "us_place_500k.shp"
      ])
      expect(instance.send(:zip_url, described_class::LAYERS.second)).to eq(
        "https://tech-team-data.s3.amazonaws.com/national-dw-tool/staging/cartographic-boundaries/us_county_500k.zip"
      )
    end

    it "raises a clear error when ETL_SOURCE_URL is missing" do
      ENV.delete("ETL_SOURCE_URL")

      expect { instance.send(:zip_url, described_class::LAYERS.first) }
        .to raise_error(RuntimeError, /ETL_SOURCE_URL is not set/)
    end

    it "raises if ogr2ogr is not available" do
      allow(instance).to receive(:system).with("which ogr2ogr > /dev/null 2>&1").and_return(false)

      expect { instance.load }.to raise_error(RuntimeError, /ogr2ogr not found/)
    end

    context "with ogr2ogr available" do
      let(:ogr2ogr_calls) { [] }

      before do
        allow(instance).to receive(:system) do |*args|
          if args.first.is_a?(Hash) && args[1] == "ogr2ogr"
            ogr2ogr_calls << args
          elsif args.first == "ogr2ogr"
            ogr2ogr_calls << args
          elsif args.first == "unzip"
            FileUtils.mkdir_p(tmp_dir)
            %w[us_state_500k us_county_500k us_place_500k].each do |name|
              FileUtils.touch(tmp_dir.join("#{name}.shp"))
            end
          elsif args == ["which ogr2ogr > /dev/null 2>&1"]
            # no-op: shouldn't be hit since ogr2ogr check uses the string form
          end
          true
        end

        allow(instance).to receive(:system).with("which ogr2ogr > /dev/null 2>&1").and_return(true)

        allow(instance).to receive(:stream_to_tempfile) { fake_zip_tempfile }

        conn = ApplicationRecord.connection
        allow(conn).to receive(:execute).and_call_original
        allow(conn).to receive(:execute).with(/TRUNCATE|INSERT INTO "?cartographic|DROP TABLE IF EXISTS/).and_return(nil)
        allow(conn).to receive(:select_value).and_call_original
        allow(conn).to receive(:select_value).with(/SELECT COUNT/).and_return(100)
      end

      it "calls ogr2ogr for each of the three shapefile layers" do
        instance.load

        expect(ogr2ogr_calls.size).to eq(3)
        expect(ogr2ogr_calls[0].flatten).to include("cartographic_states_staging")
        expect(ogr2ogr_calls[1].flatten).to include("cartographic_counties_staging")
        expect(ogr2ogr_calls[2].flatten).to include("cartographic_places_staging")
      end

      it "uses PROMOTE_TO_MULTI and EPSG:4326 for correct geometry handling" do
        instance.load

        ogr2ogr_calls.each do |args|
          expect(args.flatten).to include("PROMOTE_TO_MULTI")
          expect(args.flatten).to include("EPSG:4326")
        end
      end

      it "does not bust or warm map tiles after a successful boundary refresh" do
        expect(Etl::PostImportSteps).not_to receive(:bust_tile_cache)
        expect(Etl::PostImportSteps).not_to receive(:bust_cartographic_boundary_tile_cache)
        expect(TileCacheWarmJob).not_to receive(:perform_later)

        instance.load
      end

      it "records one DataImport after all boundary layers load successfully" do
        expect { instance.load }.to change(DataImport, :count).by(1)

        import = DataImport.last
        expect(import.file_url).to eq("cartographic-boundaries")
        expect(import.imported_at).to be_within(5.seconds).of(Time.current)
      end

      it "returns an imported ImportResult after the audit row is recorded" do
        result = instance.load

        expect(result).to have_attributes(
          file_key: "cartographic-boundaries",
          status: :imported,
          full_refresh_required: true
        )
        expect(DataImport.last.file_url).to eq("cartographic-boundaries")
      end

      private

      def fake_zip_tempfile
        Tempfile.new(["boundary", ".zip"]).tap do |file|
          file.write("fake-zip-data")
          file.rewind
        end
      end
    end

    context "when a later layer fails after earlier layers loaded" do
      before do
        allow(instance).to receive(:system) do |*args|
          if args.first == "unzip"
            FileUtils.mkdir_p(tmp_dir)
            %w[us_state_500k us_county_500k].each do |name|
              FileUtils.touch(tmp_dir.join("#{name}.shp"))
            end
          end
          true
        end
        allow(instance).to receive(:system).with("which ogr2ogr > /dev/null 2>&1").and_return(true)

        allow(instance).to receive(:stream_to_tempfile) { fake_zip_tempfile }

        conn = ApplicationRecord.connection
        allow(conn).to receive(:execute).and_call_original
        allow(conn).to receive(:execute).with(/TRUNCATE|INSERT INTO "?cartographic|DROP TABLE IF EXISTS/).and_return(nil)
        allow(conn).to receive(:select_value).and_call_original
        allow(conn).to receive(:select_value).with(/SELECT COUNT/).and_return(100)
      end

      it "does not record a DataImport" do
        count_before = DataImport.count

        expect { instance.load }.to raise_error(RuntimeError, /Shapefile not found: .*us_place_500k\.shp/)
        expect(DataImport.count).to eq(count_before)
      end

      private

      def fake_zip_tempfile
        Tempfile.new(["boundary", ".zip"]).tap do |file|
          file.write("fake-zip-data")
          file.rewind
        end
      end
    end
  end
end
