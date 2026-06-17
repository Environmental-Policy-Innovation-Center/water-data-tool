require "rails_helper"

RSpec.describe TileCacheWarmJob, type: :job do
  before do
    allow(TileGenerator).to receive(:generate_tile!)
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:flush)
  end

  describe "#perform" do
    it "warms each layer once it is eligible for the zoom level" do
      # Stub tile_coordinates to return one coord per zoom to keep the test fast.
      # The coordinate math is covered by the #tile_coordinates unit tests below.
      allow_any_instance_of(described_class).to receive(:tile_coordinates).and_return([[0, 0]])

      described_class.perform_now

      TileGenerator.layers.each do |layer|
        expect(TileGenerator).to have_received(:generate_tile!)
          .with(layer, anything, 0, 0).at_least(:once)
      end
    end

    it "continues warming remaining tiles when one layer raises" do
      call_count = 0
      allow(TileGenerator).to receive(:generate_tile!) { |layer, z, x, y|
        raise "boom" if z == 1 && x == 0 && y == 0 && layer == "pws"
        call_count += 1
      }

      expect { described_class.perform_now }.not_to raise_error
      expect(call_count).to be > 0
    end

    it "does not warm public water system tiles for low-zoom overview tiles" do
      allow_any_instance_of(described_class).to receive(:tile_coordinates).and_return([[0, 0]])

      described_class.perform_now

      expect(TileGenerator).not_to have_received(:generate_tile!).with("pws", 3, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("states", 3, 0, 0)
    end

    it "warms public water system tiles at state selection zooms" do
      allow_any_instance_of(described_class).to receive(:tile_coordinates).and_return([[0, 0]])

      described_class.perform_now

      expect(TileGenerator).to have_received(:generate_tile!).with("pws", 5, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("pws", 6, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("pws", 7, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("counties", 5, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("counties", 6, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("counties", 7, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("states", 5, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("states", 6, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("states", 7, 0, 0)
    end

    it "resumes warming public water system tiles at system browsing zoom" do
      allow_any_instance_of(described_class).to receive(:tile_coordinates).and_return([[0, 0]])

      described_class.perform_now

      expect(TileGenerator).to have_received(:generate_tile!).with("pws", 8, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("places", 8, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("counties", 8, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("states", 8, 0, 0)
    end

    it "defaults to warming eligible layers through z8" do
      allow_any_instance_of(described_class).to receive(:tile_coordinates).and_return([[0, 0]])

      described_class.perform_now

      expect(TileGenerator).to have_received(:generate_tile!).with("states", 0, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("states", 8, 0, 0)
      expect(TileGenerator).not_to have_received(:generate_tile!).with(anything, 9, anything, anything)
    end

    it "does not warm zooms above max_zoom" do
      allow_any_instance_of(described_class).to receive(:tile_coordinates).and_return([[0, 0]])

      described_class.perform_now(max_zoom: 5)

      expect(TileGenerator).to have_received(:generate_tile!).with("states", 5, 0, 0)
      expect(TileGenerator).not_to have_received(:generate_tile!).with(anything, 6, anything, anything)
    end

    it "warms only requested layers when layers are provided" do
      allow_any_instance_of(described_class).to receive(:tile_coordinates).and_return([[0, 0]])

      described_class.perform_now(layers: %w[states counties places])

      expect(TileGenerator).to have_received(:generate_tile!).with("states", 8, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("counties", 8, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("places", 8, 0, 0)
      expect(TileGenerator).not_to have_received(:generate_tile!).with("pws", anything, anything, anything)
    end

    it "uses zoom eligibility after filtering requested layers" do
      allow_any_instance_of(described_class).to receive(:tile_coordinates).and_return([[0, 0]])

      described_class.perform_now(max_zoom: 5, layers: %w[states counties places])

      expect(TileGenerator).to have_received(:generate_tile!).with("states", 5, 0, 0)
      expect(TileGenerator).to have_received(:generate_tile!).with("counties", 5, 0, 0)
      expect(TileGenerator).not_to have_received(:generate_tile!).with("places", 5, 0, 0)
    end
  end

  describe "#tile_coordinates" do
    subject(:job) { described_class.new }

    it "returns far fewer coordinates than the full grid at high zoom" do
      full_grid_z7 = (2**7)**2  # 16,384 — the blind approach
      us_only_z7 = job.send(:tile_coordinates, 7).size
      expect(us_only_z7).to be < full_grid_z7 / 10
    end

    it "includes corner tiles for all defined regions at z7" do
      coords = job.send(:tile_coordinates, 7)

      described_class::REGION_BOUNDS.each do |west, south, east, north|
        x_min, x_max, y_min, y_max = job.send(:bbox_to_tile_range, west, south, east, north, 7)
        expect(coords).to include([x_min, y_min]), "expected NW corner for bbox [#{west},#{south},#{east},#{north}]"
        expect(coords).to include([x_max, y_max]), "expected SE corner for bbox [#{west},#{south},#{east},#{north}]"
      end
    end

    it "produces no duplicate coordinates" do
      coords = job.send(:tile_coordinates, 7)
      expect(coords.uniq.size).to eq(coords.size)
    end
  end
end
