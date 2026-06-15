require "rails_helper"

# PostImportSteps runs raw PostGIS SQL against the live test database.
# Tests verify that each step runs without error and produces the expected
# spatial data given a pre-seeded ServiceAreaGeometry.
#
# Geometries are inserted directly via SQL to avoid RGeo dependency in specs.

# A small valid MultiPolygon covering part of Vermont (SRID 4326).
VERMONT_WKT = "MULTIPOLYGON(((-72.6 44.2, -72.5 44.2, -72.5 44.3, -72.6 44.3, -72.6 44.2)))".freeze

# A bounding box large enough to contain Vermont — used as the cartographic
# state geometry so assign_state_codes can match centroids.
VERMONT_STATE_WKT = "MULTIPOLYGON(((-73.5 42.7, -71.5 42.7, -71.5 45.2, -73.5 45.2, -73.5 42.7)))".freeze

RSpec.describe Etl::PostImportSteps do
  let(:conn) { ApplicationRecord.connection }

  def insert_geometry(pwsid, wkt)
    conn.execute(<<~SQL)
      INSERT INTO service_area_geometries (pwsid, geom, created_at, updated_at)
      VALUES (
        #{conn.quote(pwsid)},
        ST_GeomFromText(#{conn.quote(wkt)}, 4326),
        NOW(), NOW()
      )
      ON CONFLICT (pwsid) DO UPDATE SET geom = EXCLUDED.geom
    SQL
  end

  def insert_state(stusps, wkt)
    conn.execute(<<~SQL)
      INSERT INTO cartographic_states (gid, stusps, geoid, name, statefp, geom)
      VALUES (
        1,
        #{conn.quote(stusps)},
        '50',
        'Vermont',
        '50',
        ST_GeomFromText(#{conn.quote(wkt)}, 4326)
      )
      ON CONFLICT (gid) DO UPDATE SET stusps = EXCLUDED.stusps, geom = EXCLUDED.geom
    SQL
  end

  before do
    create(:public_water_system, pwsid: "VT0000001")
    insert_geometry("VT0000001", VERMONT_WKT)
  end

  describe ".fix_invalid_geometries" do
    it "runs without error" do
      expect { described_class.fix_invalid_geometries }.not_to raise_error
    end
  end

  describe ".generate_centroids" do
    it "populates the centroid column for all service area geometries" do
      described_class.generate_centroids
      sag = ServiceAreaGeometry.find_by(pwsid: "VT0000001")
      expect(sag.centroid).not_to be_nil
    end
  end

  describe ".assign_state_codes" do
    before do
      insert_state("VT", VERMONT_STATE_WKT)
      described_class.generate_centroids
    end

    it "sets stusps on public water systems whose centroid falls within a state geometry" do
      described_class.assign_state_codes
      expect(PublicWaterSystem.find_by(pwsid: "VT0000001").stusps).to eq("VT")
    end
  end

  describe ".build_place_crosswalks" do
    it "runs without error" do
      expect { described_class.build_place_crosswalks }.not_to raise_error
    end
  end

  describe ".rebuild_spatial_indexes" do
    it "rebuilds spatial indexes concurrently before analyzing the table" do
      connection = instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter)
      allow(ApplicationRecord).to receive(:connection).and_return(connection)

      expect(connection).to receive(:execute).with("REINDEX INDEX CONCURRENTLY index_service_area_geometries_on_geom").ordered
      expect(connection).to receive(:execute).with("REINDEX INDEX CONCURRENTLY index_service_area_geometries_on_centroid").ordered
      expect(connection).to receive(:execute).with("ANALYZE service_area_geometries").ordered

      described_class.rebuild_spatial_indexes
    end
  end

  describe ".bust_tile_cache" do
    it "deletes all rows from the tile_cache table" do
      create(:tile_cache, layer: "pws", z: 5, x: 8, y: 12)
      create(:tile_cache, layer: "states", z: 3, x: 2, y: 1)

      expect { described_class.bust_tile_cache }
        .to change { TileCache.count }.from(2).to(0)
    end

    it "runs without error when the cache is already empty" do
      expect { described_class.bust_tile_cache }.not_to raise_error
    end
  end

  describe ".call" do
    before do
      insert_state("VT", VERMONT_STATE_WKT)
      allow(CartographicBoundaries).to receive(:load)
      allow(described_class).to receive(:rebuild_spatial_indexes)
      allow(TileCacheWarmJob).to receive(:perform_later)
    end

    it "is a no-op when imported_files is empty" do
      expect(TileCacheWarmJob).not_to receive(:perform_later)
      expect(CartographicBoundaries).not_to receive(:load)
      described_class.call(imported_files: [])
    end

    it "busts tile cache and warms tiles for non-geometry imports" do
      expect(TileCacheWarmJob).to receive(:perform_later)
      expect(CartographicBoundaries).not_to receive(:load)
      described_class.call(imported_files: ["epa_sabs"])
    end

    it "loads CartographicBoundaries for geometry imports even when boundaries are already loaded" do
      allow(CartographicBoundaries).to receive(:loaded?).and_return(true)
      expect(CartographicBoundaries).to receive(:load)
      described_class.call(imported_files: ["epa_sabs_geoms"])
    end

    it "busts tile cache and warms tiles after geometry enrichment completes" do
      calls = []

      allow(described_class).to receive(:fix_invalid_geometries) { calls << :fix_invalid_geometries }
      allow(described_class).to receive(:generate_centroids) { calls << :generate_centroids }
      allow(CartographicBoundaries).to receive(:load) { calls << :load_boundaries }
      allow(described_class).to receive(:assign_state_codes) { calls << :assign_state_codes }
      allow(described_class).to receive(:rebuild_spatial_indexes) { calls << :rebuild_spatial_indexes }
      allow(described_class).to receive(:build_place_crosswalks) { calls << :build_place_crosswalks }
      allow(described_class).to receive(:bust_tile_cache) { calls << :bust_tile_cache }
      allow(TileCacheWarmJob).to receive(:perform_later) { calls << :warm_tiles }

      described_class.call(imported_files: ["epa_sabs_geoms"])

      expect(calls).to eq([
        :fix_invalid_geometries,
        :generate_centroids,
        :load_boundaries,
        :assign_state_codes,
        :rebuild_spatial_indexes,
        :build_place_crosswalks,
        :bust_tile_cache,
        :warm_tiles
      ])
    end

    it "runs all steps in sequence without error" do
      expect { described_class.call(imported_files: ["epa_sabs_geoms"]) }.not_to raise_error
    end

    it "populates centroids as part of the full run" do
      described_class.call(imported_files: ["epa_sabs_geoms"])
      sag = ServiceAreaGeometry.find_by(pwsid: "VT0000001")
      expect(sag.centroid).not_to be_nil
    end

    it "assigns state codes as part of the full run" do
      described_class.call(imported_files: ["epa_sabs_geoms"])
      expect(PublicWaterSystem.find_by(pwsid: "VT0000001").stusps).to eq("VT")
    end
  end
end
