require "rails_helper"

RSpec.describe TileCacheWarmJob, type: :job do
  describe "#perform without a zoom_level argument" do
    it "enqueues a separate job for each zoom level 0 through MAX_WARM_ZOOM" do
      expect {
        described_class.perform_now
      }.to have_enqueued_job(described_class)
        .exactly(described_class::MAX_WARM_ZOOM + 1).times
    end
  end

  describe "#perform with a zoom_level argument" do
    it "generates tiles for every coordinate at the given zoom level" do
      call_count = 0
      allow(TileGenerator).to receive(:generate_tile!) { call_count += 1 }

      described_class.new.perform(2)

      # z2: 4x4 grid = 16 coords × 5 layers = 80 calls
      expect(call_count).to eq(16 * 5)
    end

    it "calls generate_tile! (skip-cache variant) for each layer" do
      layers_called = []
      allow(TileGenerator).to receive(:generate_tile!) { |layer, _z, _x, _y|
        layers_called << layer
      }

      described_class.new.perform(0)

      expect(layers_called).to match_array(TileGenerator.layers)
    end

    it "continues to the next tile coordinate when one tile fails" do
      call_args = []
      allow(TileGenerator).to receive(:generate_tile!) { |layer, z, x, y|
        raise "boom" if x == 0 && y == 0 && layer == "pws"
        call_args << [layer, z, x, y]
      }

      expect { described_class.new.perform(1) }.not_to raise_error

      # z1 = 2x2 grid. (0,0) partially fails (pws raises, other 4 layers still run),
      # remaining 3 coordinates should each get all 5 layers = 15 calls,
      # plus the 4 non-pws layers at (0,0) = 4. Total = 19.
      # Actually the rescue is around the whole (x,y) coordinate, so (0,0) skips entirely.
      # Remaining: 3 coords × 5 layers = 15
      expect(call_args.length).to eq(15)
    end
  end
end
