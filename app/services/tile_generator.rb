module TileGenerator
  LAYERS = %w[pws pws_points places counties states].freeze

  # Simplification tolerances keyed by max zoom level.
  SIMPLIFICATION = [
    [4, 0.05],
    [5, 0.01],
    [6, 0.005],
    [7, 0.001],
    [8, 0.0005],
    [9, 0.0001],
    [10, 0.00005],
    [11, 0.00001]
  ].freeze

  module_function

  def layers
    LAYERS
  end

  def simplification_tolerance(z)
    SIMPLIFICATION.each do |max_z, tolerance|
      return tolerance if z <= max_z
    end
    0
  end

  # Generate (or fetch from cache) a single layer tile.
  def generate_tile(layer, z, x, y)
    cached = TileCache.find_by(layer: layer, z: z, x: x, y: y)
    return cached.mvt.to_s if cached

    generate_tile!(layer, z, x, y)
  end

  # Generate and persist a tile, skipping cache lookup. Used by the warm
  # job where the cache is known to be empty.
  def generate_tile!(layer, z, x, y)
    simp = simplification_tolerance(z)
    mvt = generate_layer(layer, z, x, y, simp)
    persist_tile(layer, z, x, y, mvt)
    mvt
  end

  # Build a complete tile by concatenating all layers.
  def build_tile(z, x, y)
    cached = TileCache.where(z: z, x: x, y: y).index_by(&:layer)
    simp = simplification_tolerance(z)

    LAYERS.each_with_object("".b) do |layer, result|
      mvt = if cached[layer]
        cached[layer].mvt.to_s
      else
        generated = generate_layer(layer, z, x, y, simp)
        persist_tile(layer, z, x, y, generated)
        generated
      end

      result << mvt if mvt.present?
    end
  end

  # --- private below this line (module_function makes all methods public,
  #     so we rely on convention — callers should use the API above) ---

  def generate_layer(layer, z, x, y, simp)
    sql = layer_sql(layer, z, x, y, simp)
    return "".b if sql.nil?

    rows = ApplicationRecord.connection.execute(sql)
    rows.first&.dig("mvt").then { |raw| raw ? PG::Connection.unescape_bytea(raw) : "".b }
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("[TileGenerator] SQL error for #{layer}/#{z}/#{x}/#{y}: #{e.message}")
    "".b
  end

  def persist_tile(layer, z, x, y, mvt_data)
    TileCache.upsert(
      {layer: layer, z: z, x: x, y: y, mvt: mvt_data},
      unique_by: %i[layer z x y]
    )
  rescue ActiveRecord::RecordNotUnique
    # Another request wrote it concurrently — not an error
  end

  # rubocop:disable Metrics/MethodLength
  # Safety: z, x, y are integers and simp is a hardcoded Float from
  # SIMPLIFICATION. No user-controlled data is interpolated.
  def layer_sql(layer, z, x, y, simp)
    case layer
    when "pws"
      <<~SQL.squish
        SELECT ST_AsMVT(t, 'pws', 4096, 'mvtgeom') AS mvt
        FROM (
          SELECT
            ST_AsMVTGeom(
              ST_SimplifyPreserveTopology(ST_Transform(sag.geom, 3857), #{simp}),
              ST_TileEnvelope(#{z}, #{x}, #{y}), 4096, 0, false
            ) AS mvtgeom,
            pws.pwsid, pws.stusps, pws.pws_name, pws.symbology_field,
            pws.pop_cat_5, pws.population_served_count, pws.service_connections_count
          FROM service_area_geometries sag
          JOIN public_water_systems pws ON pws.pwsid = sag.pwsid
          WHERE sag.geom IS NOT NULL
            AND sag.geom && ST_Transform(ST_TileEnvelope(#{z}, #{x}, #{y}), 4326)
        ) t
      SQL
    when "pws_points"
      <<~SQL.squish
        SELECT ST_AsMVT(t, 'pws_points', 4096, 'mvtgeom') AS mvt
        FROM (
          SELECT
            ST_AsMVTGeom(
              ST_Transform(sag.centroid, 3857),
              ST_TileEnvelope(#{z}, #{x}, #{y}), 4096, 0, false
            ) AS mvtgeom,
            pws.pwsid, pws.stusps, pws.pws_name, pws.symbology_field,
            pws.pop_cat_5, pws.population_served_count, pws.service_connections_count,
            pws.counties, pws.primacy_agency
          FROM service_area_geometries sag
          JOIN public_water_systems pws ON pws.pwsid = sag.pwsid
          WHERE sag.centroid IS NOT NULL
            AND sag.centroid && ST_Transform(ST_TileEnvelope(#{z}, #{x}, #{y}), 4326)
        ) t
      SQL
    when "places"
      <<~SQL.squish
        SELECT ST_AsMVT(t, 'places', 4096, 'mvtgeom') AS mvt
        FROM (
          SELECT
            ST_AsMVTGeom(
              ST_SimplifyPreserveTopology(ST_Transform(cp.geom, 3857), #{simp}),
              ST_TileEnvelope(#{z}, #{x}, #{y}), 4096, 0, false
            ) AS mvtgeom,
            cp.geoid,
            cp.name || ', ' || cp.stusps AS name,
            array_to_json(array_agg(psc.pwsid)) AS place_pwsids
          FROM cartographic_places cp
          LEFT JOIN place_system_crosswalks psc
            ON cp.geoid = psc.geoid
            AND (psc.fraction_of_service_area >= 0.5 OR psc.fraction_of_place >= 0.5)
          WHERE cp.geom IS NOT NULL
            AND cp.geom && ST_Transform(ST_TileEnvelope(#{z}, #{x}, #{y}), 4326)
          GROUP BY cp.geoid, cp.name, cp.stusps, cp.geom
        ) t
      SQL
    when "counties"
      <<~SQL.squish
        SELECT ST_AsMVT(t, 'counties', 4096, 'mvtgeom') AS mvt
        FROM (
          SELECT
            ST_AsMVTGeom(
              ST_SimplifyPreserveTopology(ST_Transform(cc.geom, 3857), #{simp}),
              ST_TileEnvelope(#{z}, #{x}, #{y}), 4096, 0, false
            ) AS mvtgeom,
            cc.geoid,
            cc.namelsad || ', ' || cc.stusps AS name
          FROM cartographic_counties cc
          WHERE cc.geom IS NOT NULL
            AND cc.geom && ST_Transform(ST_TileEnvelope(#{z}, #{x}, #{y}), 4326)
        ) t
      SQL
    when "states"
      <<~SQL.squish
        SELECT ST_AsMVT(t, 'states', 4096, 'mvtgeom') AS mvt
        FROM (
          SELECT
            ST_AsMVTGeom(
              ST_SimplifyPreserveTopology(ST_Transform(cs.geom, 3857), #{simp}),
              ST_TileEnvelope(#{z}, #{x}, #{y}), 4096, 0, false
            ) AS mvtgeom,
            cs.geoid, cs.stusps, cs.name
          FROM cartographic_states cs
          WHERE cs.geom IS NOT NULL
            AND cs.geom && ST_Transform(ST_TileEnvelope(#{z}, #{x}, #{y}), 4326)
        ) t
      SQL
    end
  end
  # rubocop:enable Metrics/MethodLength
end
