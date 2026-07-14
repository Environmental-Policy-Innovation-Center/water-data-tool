module TileGenerator
  LAYERS = %w[pws places counties states].freeze
  EXTENT = 4096
  BUFFER = 64
  PWS_MIN_ZOOM = 5
  PLACES_MIN_ZOOM = 8
  LOW_ZOOM_PWS_CACHE_LAYER = "pws_low_poly_v1"
  PWS_GENERALIZATION_PROFILES = [
    {zoom_range: 0..4, column: "geom_z0_4", tolerance: 0.05},
    {zoom_range: 5..5, column: "geom_z5", tolerance: 0.01},
    {zoom_range: 6..6, column: "geom_z6", tolerance: 0.005},
    {zoom_range: 7..7, column: "geom_z7", tolerance: 0.001}
  ].freeze
  GENERALIZED_GEOMETRY_ASSIGNMENTS_ON_GEOM_SQL = PWS_GENERALIZATION_PROFILES.map { |profile|
    "#{profile[:column]} = ST_Multi(ST_SimplifyPreserveTopology(geom, #{profile[:tolerance]}))"
  }.join(",\n          ").freeze
  GENERALIZED_GEOMETRY_ASSIGNMENTS_ON_SAG_GEOM_SQL = PWS_GENERALIZATION_PROFILES.map { |profile|
    "#{profile[:column]} = ST_Multi(ST_SimplifyPreserveTopology(sag.geom, #{profile[:tolerance]}))"
  }.join(",\n            ").freeze
  GENERALIZED_GEOMETRY_MISSING_SQL = PWS_GENERALIZATION_PROFILES.map { |profile|
    "#{profile[:column]} IS NULL"
  }.join("\n                OR ").freeze

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

  def layers_for_zoom(z)
    return %w[pws states] if z < PWS_MIN_ZOOM

    layers = LAYERS.dup
    layers.delete("places") if z < PLACES_MIN_ZOOM
    layers
  end

  def simplification_tolerance(z)
    SIMPLIFICATION.each do |max_z, tolerance|
      return tolerance if z <= max_z
    end
    0
  end

  def layer_simplification_tolerance(layer, z)
    simplification_tolerance(z)
  end

  # Generate (or fetch from cache) a single layer tile.
  def generate_tile(layer, z, x, y)
    cached = TileCache.find_by(layer: cache_layer(layer, z), z: z, x: x, y: y)
    return cached.mvt.to_s if cached

    generate_tile!(layer, z, x, y)
  end

  # Generate and persist a tile, skipping cache lookup. Used by the warm
  # job where the cache is known to be empty.
  def generate_tile!(layer, z, x, y)
    simp = layer_simplification_tolerance(layer, z)
    mvt = generate_layer(layer, z, x, y, simp)
    persist_tile(layer, z, x, y, mvt)
    mvt
  end

  # Build a complete tile by concatenating all layers.
  def build_tile(z, x, y)
    cached = TileCache.where(z: z, x: x, y: y).index_by(&:layer)

    layers_for_zoom(z).each_with_object("".b) do |layer, result|
      cache_key = cache_layer(layer, z)
      mvt = if cached[cache_key]
        cached[cache_key].mvt.to_s
      else
        simp = layer_simplification_tolerance(layer, z)
        generated = generate_layer(layer, z, x, y, simp)
        persist_tile(layer, z, x, y, generated)
        generated
      end

      result << mvt if mvt.present?
    end
  end

  # --- private below this line (module_function makes all methods public,
  #     so we rely on convention — callers should use the API above) ---

  def generate_layer!(layer, z, x, y, simp)
    sql = layer_sql(layer, z, x, y, simp)
    return "".b if sql.nil?

    rows = ApplicationRecord.connection.execute(sql)
    rows.first&.dig("mvt").then { |raw| raw ? PG::Connection.unescape_bytea(raw) : "".b }
  end

  def generate_layer(layer, z, x, y, simp)
    generate_layer!(layer, z, x, y, simp)
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("[TileGenerator] SQL error for #{layer}/#{z}/#{x}/#{y}: #{e.message}")
    "".b
  end

  def persist_tile(layer, z, x, y, mvt_data)
    TileCache.upsert(
      {layer: cache_layer(layer, z), z: z, x: x, y: y, mvt: mvt_data},
      unique_by: %i[layer z x y]
    )
  rescue ActiveRecord::RecordNotUnique
    # Another request wrote it concurrently — not an error
  end

  # rubocop:disable Metrics/MethodLength
  # Safety: z, x, y are integers and simp is a hardcoded Float from
  # SIMPLIFICATION. No user-controlled data is interpolated.
  def layer_sql(layer, z, x, y, simp)
    tile_envelope = tile_envelope_sql(z, x, y)
    query_envelope = tile_envelope_sql(z, x, y, margin: true)

    case layer
    when "pws"
      low_zoom = z < PWS_MIN_ZOOM
      attrs = if low_zoom
        "pws.pwsid, pws.stusps"
      else
        <<~SQL.squish
          pws.pwsid, pws.stusps, pws.pws_name, pws.symbology_field,
          pws.pop_cat_5, pws.population_served_count, pws.service_connections_count,
          pws.area_sq_miles, pws.phone_number, pws.owner_type, pws.years_operating,
          vs.total_violations_10yr
        SQL
      end
      violations_join = low_zoom ? "" : "LEFT JOIN violations_summaries vs ON vs.pwsid = pws.pwsid"

      <<~SQL.squish
        SELECT ST_AsMVT(t, 'pws', #{EXTENT}, 'mvtgeom') AS mvt
        FROM (
          SELECT
            ST_AsMVTGeom(
              ST_Transform(#{pws_geometry_sql(z, simp)}, 3857),
              #{tile_envelope}, #{EXTENT}, #{BUFFER}, true
            ) AS mvtgeom,
            #{attrs}
          FROM service_area_geometries sag
          JOIN public_water_systems pws ON pws.pwsid = sag.pwsid
          #{violations_join}
          WHERE sag.geom IS NOT NULL
            AND sag.geom && ST_Transform(#{query_envelope}, 4326)
        ) t
      SQL
    when "places"
      <<~SQL.squish
        SELECT ST_AsMVT(t, 'places', #{EXTENT}, 'mvtgeom') AS mvt
        FROM (
          SELECT
            ST_AsMVTGeom(
              ST_Transform(ST_SimplifyPreserveTopology(cp.geom, #{simp}), 3857),
              #{tile_envelope}, #{EXTENT}, #{BUFFER}, true
            ) AS mvtgeom,
            cp.geoid,
            cp.name || ', ' || cp.stusps AS name,
            array_to_json(array_agg(psc.pwsid)) AS place_pwsids
          FROM cartographic_places cp
          LEFT JOIN place_system_crosswalks psc
            ON cp.geoid = psc.geoid
            AND (psc.fraction_of_service_area >= 0.5 OR psc.fraction_of_place >= 0.5)
          WHERE cp.geom IS NOT NULL
            AND cp.geom && ST_Transform(#{query_envelope}, 4326)
          GROUP BY cp.geoid, cp.name, cp.stusps, cp.geom
        ) t
      SQL
    when "counties"
      <<~SQL.squish
        SELECT ST_AsMVT(t, 'counties', #{EXTENT}, 'mvtgeom') AS mvt
        FROM (
          SELECT
            ST_AsMVTGeom(
              ST_Transform(ST_SimplifyPreserveTopology(cc.geom, #{simp}), 3857),
              #{tile_envelope}, #{EXTENT}, #{BUFFER}, true
            ) AS mvtgeom,
            cc.geoid,
            cc.namelsad || ', ' || cc.stusps AS name
          FROM cartographic_counties cc
          WHERE cc.geom IS NOT NULL
            AND cc.geom && ST_Transform(#{query_envelope}, 4326)
        ) t
      SQL
    when "states"
      <<~SQL.squish
        SELECT ST_AsMVT(t, 'states', #{EXTENT}, 'mvtgeom') AS mvt
        FROM (
          SELECT
            ST_AsMVTGeom(
              ST_Transform(ST_SimplifyPreserveTopology(cs.geom, #{simp}), 3857),
              #{tile_envelope}, #{EXTENT}, #{BUFFER}, true
            ) AS mvtgeom,
            cs.geoid, cs.stusps, cs.name
          FROM cartographic_states cs
          WHERE cs.geom IS NOT NULL
            AND cs.geom && ST_Transform(#{query_envelope}, 4326)
        ) t
      SQL
    end
  end

  def tile_envelope_sql(z, x, y, margin: false)
    return "ST_TileEnvelope(#{z}, #{x}, #{y}, margin => #{BUFFER}.0 / #{EXTENT})" if margin

    "ST_TileEnvelope(#{z}, #{x}, #{y})"
  end

  def pws_geometry_sql(z, simp)
    column = generalized_geometry_profile_for_zoom(z)&.fetch(:column)
    fallback = "ST_SimplifyPreserveTopology(sag.geom, #{simp})"

    column ? "COALESCE(sag.#{column}, #{fallback})" : fallback
  end
  # rubocop:enable Metrics/MethodLength

  def generalized_geometry_profile_for_zoom(z)
    PWS_GENERALIZATION_PROFILES.find { |profile| profile[:zoom_range].cover?(z) }
  end

  def cache_layer(layer, z)
    return LOW_ZOOM_PWS_CACHE_LAYER if layer == "pws" && z < PWS_MIN_ZOOM

    layer
  end
end
