require "rails_helper"

RSpec.describe TileCacheRefreshJob, type: :job do
  it "uses the tile_refresh queue" do
    expect(described_class.queue_name).to eq("tile_refresh")
  end

  it "regenerates only the supplied layer coordinates" do
    allow(TileGenerator).to receive(:generate_tile!)

    described_class.perform_now(layer: "pws", z: 5, coords: [[8, 12], [9, 12]])

    expect(TileGenerator).to have_received(:generate_tile!).with("pws", 5, 8, 12)
    expect(TileGenerator).to have_received(:generate_tile!).with("pws", 5, 9, 12)
  end
end
