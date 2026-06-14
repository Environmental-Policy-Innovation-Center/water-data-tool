require "rails_helper"

RSpec.describe TileGenerator do
  let(:z) { 5 }
  let(:x) { 8 }
  let(:y) { 12 }

  describe ".layers" do
    it "returns the four expected layer names" do
      expect(described_class.layers).to eq(%w[pws places counties states])
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

  describe ".layers_for_zoom" do
    it "returns only states before state selection is available" do
      expect(described_class.layers_for_zoom(4)).to eq(%w[states])
    end

    it "adds service areas at state selection zooms" do
      expect(described_class.layers_for_zoom(5)).to eq(%w[pws counties states])
      expect(described_class.layers_for_zoom(6)).to eq(%w[pws counties states])
      expect(described_class.layers_for_zoom(7)).to eq(%w[pws counties states])
    end

    it "adds system and boundary layers at system browsing zooms" do
      expect(described_class.layers_for_zoom(8)).to eq(%w[pws places counties states])
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
      it "returns the generated MVT binary and caches it" do
        result = described_class.generate_tile("pws", z, x, y)
        cached = TileCache.find_by!(layer: "pws", z: z, x: x, y: y)
        expect(result).to eq(cached.mvt)
      end

      it "persists the generated tile to the cache" do
        expect { described_class.generate_tile("pws", z, x, y) }
          .to change { TileCache.where(layer: "pws", z: z, x: x, y: y).count }.from(0).to(1)
      end
    end
  end

  describe ".generate_tile!" do
    context "when no cached tile exists (empty database)" do
      it "returns the generated MVT binary without checking the cache" do
        expect(TileCache).not_to receive(:find_by)
        result = described_class.generate_tile!("pws", z, x, y)
        expect(result.encoding).to eq(Encoding::ASCII_8BIT)
      end

      it "persists the generated tile to the cache" do
        expect { described_class.generate_tile!("pws", z, x, y) }
          .to change { TileCache.where(layer: "pws", z: z, x: x, y: y).count }.from(0).to(1)
      end
    end
  end

  describe ".build_tile" do
    context "when all layers are cached" do
      let(:mvt_data) { "\x1a\x10tile_data".b }
      let(:layers) { described_class.layers_for_zoom(z) }

      before do
        layers.each do |layer|
          create(:tile_cache, layer: layer, z: z, x: x, y: y, mvt: mvt_data)
        end
      end

      it "returns concatenated MVT binary from all cached layers" do
        result = described_class.build_tile(z, x, y)
        expect(result.bytesize).to eq(mvt_data.bytesize * layers.size)
      end
    end

    context "when no tiles are cached" do
      it "returns concatenated MVT matching the sum of all generated layer tiles" do
        result = described_class.build_tile(z, x, y)
        expected_size = described_class.layers_for_zoom(z).sum { |layer|
          TileCache.find_by!(layer: layer, z: z, x: x, y: y).mvt.bytesize
        }
        expect(result.bytesize).to eq(expected_size)
      end

      it "generates public water system tiles at state selection zooms" do
        described_class.build_tile(5, 16, 12)

        expect(TileCache.where(layer: "pws", z: 5, x: 16, y: 12)).to exist
        expect(TileCache.where(layer: "places", z: 5, x: 16, y: 12)).to be_empty
        expect(TileCache.where(layer: "counties", z: 5, x: 16, y: 12)).to exist
        expect(TileCache.where(layer: "states", z: 5, x: 16, y: 12)).to exist
      end
    end
  end

  describe ".layer_sql" do
    it "simplifies geometries before transforming them for vector tiles" do
      sql = described_class.layer_sql("states", 3, 1, 2, 0.05)

      expect(sql).to include("ST_Transform(ST_SimplifyPreserveTopology(cs.geom, 0.05), 3857)")
      expect(sql).not_to include("ST_SimplifyPreserveTopology(ST_Transform")
    end
  end
end
