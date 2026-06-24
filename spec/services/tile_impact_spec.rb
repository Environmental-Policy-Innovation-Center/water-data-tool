require "rails_helper"

RSpec.describe TileImpact do
  let(:conn) { ApplicationRecord.connection }
  let(:vermont_wkt) { "MULTIPOLYGON(((-72.6 44.2, -72.5 44.2, -72.5 44.3, -72.6 44.3, -72.6 44.2)))" }

  def insert_geometry(pwsid, wkt)
    create(:public_water_system, pwsid: pwsid)
    conn.execute(<<~SQL)
      INSERT INTO service_area_geometries (pwsid, geom, geom_digest, created_at, updated_at)
      VALUES (
        #{conn.quote(pwsid)},
        ST_GeomFromText(#{conn.quote(wkt)}, 4326),
        'digest',
        NOW(), NOW()
      )
    SQL
  end

  def insert_place(geoid, wkt)
    conn.execute(<<~SQL)
      INSERT INTO cartographic_places (gid, geoid, name, stusps, geom)
      VALUES (
        #{conn.quote(geoid.to_i)},
        #{conn.quote(geoid)},
        'Burlington',
        'VT',
        ST_GeomFromText(#{conn.quote(wkt)}, 4326)
      )
    SQL
  end

  it "converts changed service-area bounds into deduplicated coordinates for every pws tile zoom" do
    impacts = described_class.impacts_for_bboxes([[-72.6, 44.2, -72.5, 44.3]], layers: ["pws"], margin_tiles: 1)

    expect(impacts.keys).to all(match(/\Apws:\d+\z/))
    expected_zooms = (0..described_class::MAX_ZOOM).select { |z| TileGenerator.layers_for_zoom(z).include?("pws") }
    expect(impacts.keys.map { |key| key.split(":").last.to_i }).to contain_exactly(*expected_zooms)
    expect(impacts.values).to all(satisfy { |coords| coords.uniq.size == coords.size })
  end

  it "includes adjacent edge tiles via the configured margin" do
    insert_geometry("VT0000001", vermont_wkt)

    impacts = described_class.for_pwsids(["VT0000001"], layers: ["pws"], margin_tiles: 1)
    unbuffered = described_class.for_pwsids(["VT0000001"], layers: ["pws"], margin_tiles: 0)

    expect(impacts["pws:8"].size).to be > unbuffered["pws:8"].size
  end

  it "includes additional geometry bounds in pws impacts" do
    insert_geometry("VT0000001", vermont_wkt)

    current_only = described_class.for_pwsids(["VT0000001"], layers: ["pws"], margin_tiles: 0)
    with_previous = described_class.for_pwsids(
      ["VT0000001"],
      layers: ["pws"],
      margin_tiles: 0,
      additional_bboxes: [[-124.5, 47.5, -124.4, 47.6]]
    )

    expect(with_previous["pws:8"]).to include(*current_only["pws:8"])
    expect(with_previous["pws:8"].size).to be > current_only["pws:8"].size
  end

  it "converts affected place bounds into place tile coordinates" do
    insert_place("50001", "MULTIPOLYGON(((-73.2 44.0, -72.0 44.0, -72.0 45.0, -73.2 45.0, -73.2 44.0)))")

    impacts = described_class.for_place_geoids(["50001"], layers: ["places"], margin_tiles: 0)

    expect(impacts.keys).to eq(["places:8"])
    expect(impacts["places:8"].size).to be > 1
  end

  it "enqueues refresh jobs in bounded batches" do
    allow(TileCacheRefreshJob).to receive(:perform_later)

    described_class.enqueue_refreshes({"pws:5" => [[1, 2], [3, 4], [5, 6]]}, batch_size: 2)

    expect(TileCacheRefreshJob).to have_received(:perform_later).with(layer: "pws", z: 5, coords: [[1, 2], [3, 4]])
    expect(TileCacheRefreshJob).to have_received(:perform_later).with(layer: "pws", z: 5, coords: [[5, 6]])
  end
end
