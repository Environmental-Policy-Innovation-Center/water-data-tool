require "rails_helper"

RSpec.describe "Tiles", type: :request do
  let(:z) { 5 }
  let(:x) { 8 }
  let(:y) { 12 }

  describe "GET /tiles/:z/:x/:y" do
    context "when all #{TileGenerator::LAYERS.size} layers are cached" do
      let(:layers) { TileGenerator::LAYERS }
      let(:mvt_data) { "\x1a\x10tile_data".b }

      before do
        layers.each do |layer|
          create(:tile_cache, layer: layer, z: z, x: x, y: y, mvt: mvt_data)
        end
      end

      it "returns 200" do
        get tile_path(z: z, x: x, y: y)
        expect(response).to have_http_status(:ok)
      end

      it "sets content-type to application/x-protobuf" do
        get tile_path(z: z, x: x, y: y)
        expect(response.content_type).to include("application/x-protobuf")
      end

      it "returns the concatenated MVT binary from cache without running SQL tile queries" do
        expect(ApplicationRecord.connection).not_to receive(:execute)
        get tile_path(z: z, x: x, y: y)
        expect(response.body.bytesize).to eq(mvt_data.bytesize * layers.size)
      end

      it "sets Cache-Control header" do
        get tile_path(z: z, x: x, y: y)
        expect(response.headers["Cache-Control"]).to be_present
      end
    end

    context "when no tiles are cached (empty database)" do
      it "returns 200 with an empty binary response" do
        get tile_path(z: z, x: x, y: y)
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/x-protobuf")
      end
    end

    context "with different zoom levels" do
      it "accepts zoom level 0" do
        get tile_path(z: 0, x: 0, y: 0)
        expect(response).to have_http_status(:ok)
      end

      it "accepts zoom level 12" do
        get tile_path(z: 12, x: 1000, y: 1000)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with out-of-range parameters" do
      it "rejects z above 22" do
        get tile_path(z: 23, x: 0, y: 0)
        expect(response).to have_http_status(:bad_request)
      end

      it "rejects x outside tile grid" do
        get tile_path(z: 2, x: 4, y: 0)
        expect(response).to have_http_status(:bad_request)
      end

      it "rejects y outside tile grid" do
        get tile_path(z: 2, x: 0, y: 4)
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
