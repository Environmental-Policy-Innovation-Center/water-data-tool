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

  it "loads without resolving the PostgreSQL array OID at file load time" do
    source = Rails.root.join("app/services/etl/post_import_steps.rb")

    expect { silence_warnings { load source } }.not_to raise_error
  end

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

  describe ".generate_generalized_geometries" do
    before do
      create(:public_water_system, pwsid: "VT0000002")
      insert_geometry("VT0000002", VERMONT_WKT)
    end

    it "populates all low-zoom generalized geometry columns" do
      described_class.generate_generalized_geometries

      row = conn.select_one(<<~SQL)
        SELECT
          geom_z0_4 IS NOT NULL AS geom_z0_4_present,
          geom_z5 IS NOT NULL AS geom_z5_present,
          geom_z6 IS NOT NULL AS geom_z6_present,
          geom_z7 IS NOT NULL AS geom_z7_present
        FROM service_area_geometries
        WHERE pwsid = 'VT0000001'
      SQL

      expect(row).to include(
        "geom_z0_4_present" => true,
        "geom_z5_present" => true,
        "geom_z6_present" => true,
        "geom_z7_present" => true
      )
    end

    it "can scope updates to selected pwsids" do
      described_class.generate_generalized_geometries(pwsids: ["VT0000001"])

      scoped = conn.select_one("SELECT geom_z5 IS NOT NULL AS present FROM service_area_geometries WHERE pwsid = 'VT0000001'")
      unscoped = conn.select_one("SELECT geom_z5 IS NOT NULL AS present FROM service_area_geometries WHERE pwsid = 'VT0000002'")

      expect(scoped["present"]).to be(true)
      expect(unscoped["present"]).to be(false)
    end
  end

  describe ".backfill_missing_generalized_geometries" do
    before do
      create(:public_water_system, pwsid: "VT0000002")
      insert_geometry("VT0000002", VERMONT_WKT)
      described_class.generate_generalized_geometries(pwsids: ["VT0000002"])
    end

    it "populates only rows missing generalized geometry columns" do
      already_present_updated_at = ServiceAreaGeometry.find_by!(pwsid: "VT0000002").updated_at

      described_class.backfill_missing_generalized_geometries

      missing_row = conn.select_one("SELECT geom_z7 IS NOT NULL AS present FROM service_area_geometries WHERE pwsid = 'VT0000001'")

      expect(missing_row["present"]).to be(true)
      expect(ServiceAreaGeometry.find_by!(pwsid: "VT0000002").updated_at).to eq(already_present_updated_at)
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

  describe ".bust_cartographic_boundary_tile_cache" do
    it "deletes only boundary layer rows from the tile cache" do
      create(:tile_cache, layer: "states", z: 3, x: 2, y: 1)
      create(:tile_cache, layer: "counties", z: 5, x: 8, y: 12)
      create(:tile_cache, layer: "places", z: 8, x: 76, y: 93)
      pws = create(:tile_cache, layer: "pws", z: 5, x: 9, y: 12)

      expect { described_class.bust_cartographic_boundary_tile_cache }
        .to change { TileCache.count }.from(4).to(1)

      expect(TileCache.pluck(:layer, :z, :x, :y)).to eq([[pws.layer, pws.z, pws.x, pws.y]])
    end

    it "runs without error when no boundary cache rows exist" do
      create(:tile_cache, layer: "pws", z: 5, x: 8, y: 12)

      expect { described_class.bust_cartographic_boundary_tile_cache }.not_to raise_error
      expect(TileCache.pluck(:layer)).to eq(["pws"])
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

    it "backfills missing generalized geometries when scheduled ETL has no imported files" do
      expect(described_class).to receive(:backfill_missing_generalized_geometries)

      described_class.call(import_results: [])
    end

    it "raises when normal ETL omits import result metadata" do
      expect { described_class.call }.to raise_error(ArgumentError, /import_results/)
    end

    it "raises when import_results contains non-ImportResult metadata" do
      expect { described_class.call(import_results: [:imported]) }
        .to raise_error(ArgumentError, /Etl::ImportResult/)
    end

    it "busts tile cache and warms tiles for non-geometry imports" do
      expect(TileCacheWarmJob).to receive(:perform_later)
      expect(CartographicBoundaries).not_to receive(:load)
      described_class.call(imported_files: ["epa_sabs"])
    end

    it "does not delete existing cached tiles for selective non-geometry import results" do
      create(:tile_cache, layer: "pws", z: 5, x: 8, y: 12)
      result = Etl::ImportResult.imported(file_key: "epa_sabs", changed_pwsids: ["VT0000001"], changed_layers: ["pws"])
      allow(TileImpact).to receive(:for_pwsids).and_return({"pws:5" => [[8, 12]]})
      allow(TileImpact).to receive(:enqueue_refreshes)

      described_class.call(import_results: [result])

      expect(TileCache.where(layer: "pws", z: 5, x: 8, y: 12)).to exist
      expect(TileCacheWarmJob).not_to have_received(:perform_later)
    end

    it "enqueues selective tile refreshes for changed map attributes" do
      result = Etl::ImportResult.imported(file_key: "epa_sabs", changed_pwsids: ["VT0000001"], changed_layers: ["pws"])
      impacts = {"pws:5" => [[8, 12]]}
      allow(TileImpact).to receive(:for_pwsids).and_return(impacts)
      allow(TileImpact).to receive(:enqueue_refreshes)

      described_class.call(import_results: [result])

      expect(TileImpact).to have_received(:for_pwsids).with(["VT0000001"], layers: ["pws"])
      expect(TileImpact).to have_received(:enqueue_refreshes).with(impacts)
    end

    it "does not enqueue tile work for non-map imports with changed pwsids but no changed layers" do
      result = Etl::ImportResult.imported(file_key: "sdwis_viols", changed_pwsids: ["VT0000001"], changed_layers: [])

      expect(TileImpact).not_to receive(:for_pwsids)
      expect(TileImpact).not_to receive(:enqueue_refreshes)
      expect(TileCacheWarmJob).not_to receive(:perform_later)

      described_class.call(import_results: [result])
    end

    it "uses the full refresh path when imported result metadata requires it" do
      result = Etl::ImportResult.imported(file_key: "sdwis_viols", full_refresh_required: true)

      expect(described_class).to receive(:bust_tile_cache)
      expect(TileCacheWarmJob).to receive(:perform_later)

      described_class.call(import_results: [result])
    end

    it "runs geometry post-processing scoped to changed pwsids" do
      result = Etl::ImportResult.imported(
        file_key: "epa_sabs_geoms",
        changed_pwsids: ["VT0000001"],
        changed_layers: %w[pws places],
        geometry_changed: true
      )
      calls = []

      allow(described_class).to receive(:fix_invalid_geometries) { |pwsids: nil| calls << [:fix_invalid_geometries, pwsids] }
      allow(described_class).to receive(:backfill_missing_generalized_geometries) { calls << [:backfill_missing_generalized_geometries, nil] }
      allow(described_class).to receive(:generate_centroids) { |pwsids: nil| calls << [:generate_centroids, pwsids] }
      allow(described_class).to receive(:generate_generalized_geometries) { |pwsids: nil| calls << [:generate_generalized_geometries, pwsids] }
      allow(CartographicBoundaries).to receive(:load) { calls << [:load_boundaries, nil] }
      allow(described_class).to receive(:assign_state_codes) { |pwsids: nil| calls << [:assign_state_codes, pwsids] }
      allow(described_class).to receive(:analyze_spatial_tables) { calls << [:analyze_spatial_tables, nil] }
      allow(described_class).to receive(:build_place_crosswalks) do |pwsids: nil|
        calls << [:build_place_crosswalks, pwsids]
        []
      end
      allow(TileImpact).to receive(:for_pwsids).and_return({})
      allow(TileImpact).to receive(:for_place_geoids).and_return({})
      allow(TileImpact).to receive(:enqueue_refreshes)

      described_class.call(import_results: [result])

      expect(calls).to eq([
        [:backfill_missing_generalized_geometries, nil],
        [:fix_invalid_geometries, ["VT0000001"]],
        [:generate_centroids, ["VT0000001"]],
        [:generate_generalized_geometries, ["VT0000001"]],
        [:load_boundaries, nil],
        [:assign_state_codes, ["VT0000001"]],
        [:analyze_spatial_tables, nil],
        [:build_place_crosswalks, ["VT0000001"]]
      ])
    end

    it "includes prior geometry bounds and affected place bounds in selective tile impacts" do
      result = Etl::ImportResult.imported(
        file_key: "epa_sabs_geoms",
        changed_pwsids: ["VT0000001"],
        changed_layers: %w[pws places],
        geometry_changed: true,
        previous_geometry_bboxes: [[-73.0, 44.0, -72.9, 44.1]]
      )
      allow(described_class).to receive(:fix_invalid_geometries)
      allow(described_class).to receive(:generate_centroids)
      allow(described_class).to receive(:generate_generalized_geometries)
      allow(CartographicBoundaries).to receive(:load)
      allow(described_class).to receive(:assign_state_codes)
      allow(described_class).to receive(:analyze_spatial_tables)
      allow(described_class).to receive(:build_place_crosswalks).and_return(["50001"])
      allow(TileImpact).to receive(:for_pwsids).and_return({"pws:5" => [[8, 12]]})
      allow(TileImpact).to receive(:for_place_geoids).and_return({"places:8" => [[76, 93]]})
      allow(TileImpact).to receive(:enqueue_refreshes)

      described_class.call(import_results: [result])

      expect(TileImpact).to have_received(:for_pwsids).with(
        ["VT0000001"],
        layers: ["pws"],
        additional_bboxes: [[-73.0, 44.0, -72.9, 44.1]]
      )
      expect(TileImpact).to have_received(:for_place_geoids).with(["50001"], layers: ["places"])
      expect(TileImpact).to have_received(:enqueue_refreshes).with(
        {"pws:5" => [[8, 12]], "places:8" => [[76, 93]]}
      )
    end

    it "reloads CartographicBoundaries for selective geometry imports" do
      result = Etl::ImportResult.imported(
        file_key: "epa_sabs_geoms",
        changed_pwsids: ["VT0000001"],
        changed_layers: %w[pws places],
        geometry_changed: true
      )

      allow(described_class).to receive(:fix_invalid_geometries)
      allow(described_class).to receive(:generate_centroids)
      allow(described_class).to receive(:generate_generalized_geometries)
      allow(described_class).to receive(:assign_state_codes)
      allow(described_class).to receive(:analyze_spatial_tables)
      allow(described_class).to receive(:build_place_crosswalks).and_return([])
      allow(TileImpact).to receive(:for_pwsids).and_return({})
      allow(TileImpact).to receive(:for_place_geoids).and_return({})
      allow(TileImpact).to receive(:enqueue_refreshes)

      expect(CartographicBoundaries).to receive(:load)
      described_class.call(import_results: [result])
    end

    it "busts tile cache and warms tiles after geometry enrichment completes" do
      calls = []

      allow(described_class).to receive(:fix_invalid_geometries) { calls << :fix_invalid_geometries }
      allow(described_class).to receive(:generate_centroids) { calls << :generate_centroids }
      allow(described_class).to receive(:generate_generalized_geometries) { calls << :generate_generalized_geometries }
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
        :generate_generalized_geometries,
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
