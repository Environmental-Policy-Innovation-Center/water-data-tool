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
            %w[cb_2022_us_state_500k cb_2022_us_county_500k cb_2022_us_place_500k].each do |name|
              FileUtils.touch(tmp_dir.join("#{name}.shp"))
            end
          elsif args == ["which ogr2ogr > /dev/null 2>&1"]
            # no-op: shouldn't be hit since ogr2ogr check uses the string form
          end
          true
        end

        allow(instance).to receive(:system).with("which ogr2ogr > /dev/null 2>&1").and_return(true)

        allow(Net::HTTP).to receive(:start).and_yield(stub_http_client)

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

      private

      def stub_http_client
        http = instance_double(Net::HTTP)
        response = instance_double(Net::HTTPSuccess)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(response).to receive(:read_body).and_yield("fake-zip-data")
        allow(http).to receive(:request).and_yield(response)
        http
      end
    end
  end
end
