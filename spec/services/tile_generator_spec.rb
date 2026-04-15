require "rails_helper"

RSpec.describe TileGenerator do
  let(:z) { 5 }
  let(:x) { 8 }
  let(:y) { 12 }

  describe ".layers" do
    it "returns the five expected layer names" do
      expect(described_class.layers).to eq(%w[pws pws_points places counties states])
    end
  end

  describe ".simplification_tolerance" do
    it "returns the coarsest tolerance for low zoom levels" do
      expect(described_class.simplification_tolerance(0)).to eq(0.05)
      expect(described_class.simplification_tolerance(4)).to eq(0.05)
    end

    it "returns finer tolerances for higher zoom levels" do
      expect(described_class.simplification_tolerance(6)).to eq(0.005)
      expect(described_class.simplification_tolerance(10)).to eq(0.00005)
    end

    it "returns 0 for zoom levels beyond the simplification table" do
      expect(described_class.simplification_tolerance(12)).to eq(0)
    end
  end

  describe ".generate_tile" do
    context "when a cached tile exists" do
      let(:mvt_data) { "\x1a\x10tile_data".b }

      before do
        create(:tile_cache, layer: "pws", z: z, x: x, y: y, mvt: mvt_data)
      end

      it "returns the cached MVT binary without running SQL" do
        expect(ApplicationRecord.connection).not_to receive(:execute)
        result = described_class.generate_tile("pws", z, x, y)
        expect(result).to eq(mvt_data)
      end
    end

    context "when no cached tile exists (empty database)" do
      it "returns a binary string" do
        result = described_class.generate_tile("pws", z, x, y)
        expect(result).to be_a(String)
        expect(result.encoding).to eq(Encoding::ASCII_8BIT)
      end

      it "persists the generated tile to the cache" do
        expect { described_class.generate_tile("pws", z, x, y) }
          .to change { TileCache.where(layer: "pws", z: z, x: x, y: y).count }.from(0).to(1)
      end
    end
  end

  describe ".generate_tile!" do
    context "when no cached tile exists (empty database)" do
      it "returns a binary string without checking the cache" do
        expect(TileCache).not_to receive(:find_by)
        result = described_class.generate_tile!("pws", z, x, y)
        expect(result).to be_a(String)
        expect(result.encoding).to eq(Encoding::ASCII_8BIT)
      end

      it "persists the generated tile to the cache" do
        expect { described_class.generate_tile!("pws", z, x, y) }
          .to change { TileCache.where(layer: "pws", z: z, x: x, y: y).count }.from(0).to(1)
      end
    end
  end

  describe ".build_tile" do
    context "when all 5 layers are cached" do
      let(:mvt_data) { "\x1a\x10tile_data".b }

      before do
        described_class.layers.each do |layer|
          create(:tile_cache, layer: layer, z: z, x: x, y: y, mvt: mvt_data)
        end
      end

      it "returns concatenated MVT binary from all cached layers" do
        result = described_class.build_tile(z, x, y)
        expect(result.bytesize).to eq(mvt_data.bytesize * 5)
      end
    end

    context "when no tiles are cached" do
      it "returns a binary string" do
        result = described_class.build_tile(z, x, y)
        expect(result).to be_a(String)
        expect(result.encoding).to eq(Encoding::ASCII_8BIT)
      end
    end
  end
end
