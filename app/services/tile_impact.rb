module TileImpact
  MIN_ZOOM = 0
  MAX_ZOOM = 8
  DEFAULT_MARGIN_TILES = 1
  PWSID_ARRAY_TYPE = ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(ActiveModel::Type::String.new)

  module_function

  def for_pwsids(pwsids, layers:, margin_tiles: DEFAULT_MARGIN_TILES, additional_bboxes: [])
    pwsids = Array(pwsids).compact.uniq
    layers = Array(layers).compact.uniq
    return {} if pwsids.empty? || layers.empty?

    bboxes = [bbox_for_pwsids(pwsids), *additional_bboxes].compact
    return {} if bboxes.empty?

    impacts_for_bboxes(bboxes, layers: layers, margin_tiles: margin_tiles)
  end

  def for_place_geoids(geoids, layers:, margin_tiles: DEFAULT_MARGIN_TILES)
    geoids = Array(geoids).compact.uniq
    layers = Array(layers).compact.uniq
    return {} if geoids.empty? || layers.empty?

    bbox = bbox_for_place_geoids(geoids)
    return {} unless bbox

    impacts_for_bboxes([bbox], layers: layers, margin_tiles: margin_tiles)
  end

  def impacts_for_bboxes(bboxes, layers:, margin_tiles:)
    layers.each_with_object({}) do |layer, impacts|
      (MIN_ZOOM..MAX_ZOOM).each do |z|
        next unless TileGenerator.layers_for_zoom(z).include?(layer)

        impacts["#{layer}:#{z}"] = bboxes.flat_map { |bbox|
          bbox_to_tile_coords(*bbox, z, margin_tiles: margin_tiles)
        }.uniq
      end
    end
  end

  def enqueue_refreshes(impacts, batch_size: 50)
    impacts.each do |key, coords|
      layer, z = key.split(":")
      coords.each_slice(batch_size) do |batch|
        TileCacheRefreshJob.perform_later(layer: layer, z: z.to_i, coords: batch)
      end
    end
  end

  def bbox_for_pwsids(pwsids)
    row = ApplicationRecord.connection.exec_query(
      <<~SQL,
        SELECT
          ST_XMin(bounds.box) AS west,
          ST_YMin(bounds.box) AS south,
          ST_XMax(bounds.box) AS east,
          ST_YMax(bounds.box) AS north
        FROM (
          SELECT ST_Extent(geom)::box2d AS box
          FROM service_area_geometries
          WHERE pwsid = ANY($1::text[])
            AND geom IS NOT NULL
        ) bounds
        WHERE bounds.box IS NOT NULL
      SQL
      "TileImpact#bbox_for_pwsids",
      pwsid_binds(pwsids)
    ).first
    return unless row

    %w[west south east north].map { |key| row.fetch(key).to_f }
  end

  def bbox_for_place_geoids(geoids)
    row = ApplicationRecord.connection.exec_query(
      <<~SQL,
        SELECT
          ST_XMin(bounds.box) AS west,
          ST_YMin(bounds.box) AS south,
          ST_XMax(bounds.box) AS east,
          ST_YMax(bounds.box) AS north
        FROM (
          SELECT ST_Extent(geom)::box2d AS box
          FROM cartographic_places
          WHERE geoid = ANY($1::text[])
            AND geom IS NOT NULL
        ) bounds
        WHERE bounds.box IS NOT NULL
      SQL
      "TileImpact#bbox_for_place_geoids",
      [
        ActiveRecord::Relation::QueryAttribute.new(
          "geoids",
          Array(geoids).compact.uniq,
          PWSID_ARRAY_TYPE
        )
      ]
    ).first
    return unless row

    %w[west south east north].map { |key| row.fetch(key).to_f }
  end

  def bbox_to_tile_coords(west, south, east, north, z, margin_tiles:)
    x_min, x_max, y_min, y_max = bbox_to_tile_range(west, south, east, north, z)
    n = (2**z) - 1
    x_min = (x_min - margin_tiles).clamp(0, n)
    x_max = (x_max + margin_tiles).clamp(0, n)
    y_min = (y_min - margin_tiles).clamp(0, n)
    y_max = (y_max + margin_tiles).clamp(0, n)

    (x_min..x_max).flat_map { |x| (y_min..y_max).map { |y| [x, y] } }.uniq
  end

  def bbox_to_tile_range(west, south, east, north, z)
    n = 2**z
    x_min = lon_to_tile_x(west, n)
    x_max = lon_to_tile_x(east, n)
    y_min = lat_to_tile_y(north, n)
    y_max = lat_to_tile_y(south, n)
    [x_min, x_max, y_min, y_max]
  end

  def lon_to_tile_x(lon, n)
    ((lon + 180) / 360.0 * n).floor.clamp(0, n - 1)
  end

  def lat_to_tile_y(lat_deg, n)
    lat = lat_deg.clamp(-85.05112878, 85.05112878)
    lat_rad = lat * Math::PI / 180
    ((1 - Math.log(Math.tan(lat_rad) + 1.0 / Math.cos(lat_rad)) / Math::PI) / 2 * n).floor.clamp(0, n - 1)
  end

  def pwsid_binds(pwsids)
    [
      ActiveRecord::Relation::QueryAttribute.new(
        "pwsids",
        Array(pwsids).compact.uniq,
        PWSID_ARRAY_TYPE
      )
    ]
  end
end
