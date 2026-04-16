require "rails_helper"
require "rake"

RSpec.describe "cartographic rake tasks" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("cartographic:load")
  end

  before do
    Rake::Task["cartographic:load"].reenable
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:write)
  end

  describe "cartographic:load" do
    let(:tmp_dir) { Rails.root.join("tmp/cartographic") }

    after do
      FileUtils.rm_rf(tmp_dir)
    end

    it "aborts if ogr2ogr is not available" do
      allow_any_instance_of(Object).to receive(:system).with("which ogr2ogr > /dev/null 2>&1").and_return(false)

      expect { Rake::Task["cartographic:load"].invoke }.to raise_error(SystemExit)
    end

    context "with ogr2ogr available" do
      let(:ogr2ogr_calls) { [] }

      before do
        # Track system calls; ogr2ogr uses array form, unzip uses array form
        allow_any_instance_of(Object).to receive(:system) do |_obj, *args|
          if args.first == "ogr2ogr"
            ogr2ogr_calls << args
          elsif args.first == "unzip"
            FileUtils.mkdir_p(tmp_dir)
            %w[cb_2022_us_state_500k cb_2022_us_county_500k cb_2022_us_place_500k].each do |name|
              FileUtils.touch(tmp_dir.join("#{name}.shp"))
            end
          end
          true
        end

        # Stub HTTP downloads
        allow(Net::HTTP).to receive(:start).and_yield(stub_http_client)

        # Stub SQL operations for staging table workflow
        conn = ApplicationRecord.connection
        allow(conn).to receive(:execute).and_call_original
        allow(conn).to receive(:execute).with(/TRUNCATE|INSERT INTO cartographic|DROP TABLE IF EXISTS/).and_return(nil)
        allow(conn).to receive(:select_value).and_call_original
        allow(conn).to receive(:select_value).with(/SELECT COUNT/).and_return(100)
      end

      it "calls ogr2ogr for each of the three shapefile layers" do
        Rake::Task["cartographic:load"].invoke

        expect(ogr2ogr_calls.size).to eq(3)
        expect(ogr2ogr_calls[0]).to include("cartographic_states_staging")
        expect(ogr2ogr_calls[1]).to include("cartographic_counties_staging")
        expect(ogr2ogr_calls[2]).to include("cartographic_places_staging")
      end

      it "uses PROMOTE_TO_MULTI and EPSG:4326 for correct geometry handling" do
        Rake::Task["cartographic:load"].invoke

        ogr2ogr_calls.each do |args|
          expect(args).to include("PROMOTE_TO_MULTI")
          expect(args).to include("EPSG:4326")
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
