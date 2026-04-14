require "rails_helper"

# PostImportSteps runs raw PostGIS SQL against the live test database.
# Tests verify that each step runs without error and produces the expected
# spatial data given a pre-seeded ServiceAreaGeometry.
#
# A minimal valid MultiPolygon geometry is inserted directly via SQL for
# each test to avoid RGeo dependency in specs.
# A small valid MultiPolygon covering part of Vermont, fully contained
# within the VT cartographic_state boundary (if loaded).
VERMONT_WKT = "MULTIPOLYGON(((-72.6 44.2, -72.5 44.2, -72.5 44.3, -72.6 44.3, -72.6 44.2)))".freeze

RSpec.describe Etl::PostImportSteps do
  let(:conn) { ApplicationRecord.connection }

  # Insert a real MultiPolygon geometry for VT0000001 via raw SQL so we can
  # test PostGIS operations without needing the RGeo factory in specs.
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
    it "runs without error" do
      # cartographic_states may not be loaded in test env; we just verify
      # no exception is raised and the SQL is valid
      expect { described_class.assign_state_codes }.not_to raise_error
    end
  end

  describe ".build_county_associations" do
    it "runs without error" do
      expect { described_class.build_county_associations }.not_to raise_error
    end
  end

  describe ".build_place_crosswalks" do
    it "runs without error" do
      expect { described_class.build_place_crosswalks }.not_to raise_error
    end
  end

  describe ".rebuild_spatial_indexes" do
    it "runs without error" do
      expect { described_class.rebuild_spatial_indexes }.not_to raise_error
    end
  end

  describe ".call" do
    it "runs all steps in sequence without error" do
      expect { described_class.call }.not_to raise_error
    end

    it "populates centroids as part of the full run" do
      described_class.call
      sag = ServiceAreaGeometry.find_by(pwsid: "VT0000001")
      expect(sag.centroid).not_to be_nil
    end
  end
end
