class TileCacheWarmJob < ApplicationJob
  queue_as :default

  MAX_WARM_ZOOM = 8

  # All [west, south, east, north] bounds must satisfy west < east (no antimeridian wrapping).
  REGION_BOUNDS = [
    [-125, 24, -66, 50],  # Continental US
    [-180, 51, -130, 72],  # Alaska
    [-161, 18, -154, 23],  # Hawaii
    [-68, 17, -65, 19],  # Puerto Rico
    [144, 13, 146, 16]  # Guam + CNMI
  ].freeze

  def perform
    total_start = Time.current
    total_coords = 0

    log("[TileCacheWarm] Starting smart warm for z0-z#{MAX_WARM_ZOOM}")

    (0..MAX_WARM_ZOOM).each do |z|
      total_coords += warm_zoom(z)
    end

    elapsed = (Time.current - total_start).round(1)
    log("[TileCacheWarm] Complete - #{total_coords} coordinates warmed in #{elapsed}s")
  end

  private

  def warm_zoom(z)
    started_at = Time.current
    errors = 0
    coords = tile_coordinates(z)
    total = coords.size

    layers = TileGenerator.layers_for_zoom(z)

    log("[TileCacheWarm] z#{z}: starting (#{total} coordinates, #{layers.size} layers each)")

    report_interval = [total / 4, 1].max

    coords.each_with_index do |(x, y), idx|
      layers.each do |layer|
        TileGenerator.generate_tile!(layer, z, x, y)
      rescue => e
        errors += 1
        log("[TileCacheWarm] #{layer}/z#{z}/#{x}/#{y}: #{e.class} - #{e.message}", level: :error)
      end

      if ((idx + 1) % report_interval).zero?
        pct = (((idx + 1).to_f / total) * 100).round
        log("[TileCacheWarm] z#{z}: #{pct}% (#{idx + 1}/#{total} coordinates)")
      end
    end

    elapsed = (Time.current - started_at).round(1)
    error_note = (errors > 0) ? ", #{errors} error(s)" : ""
    log("[TileCacheWarm] z#{z}: done in #{elapsed}s#{error_note}")

    total
  end

  # Unions all US region bounding boxes and deduplicates overlapping tile coords.
  def tile_coordinates(z)
    seen = Set.new
    coords = []

    REGION_BOUNDS.each do |west, south, east, north|
      x_min, x_max, y_min, y_max = bbox_to_tile_range(west, south, east, north, z)
      (x_min..x_max).each do |x|
        (y_min..y_max).each do |y|
          coords << [x, y] if seen.add?([x, y])
        end
      end
    end

    coords
  end

  def bbox_to_tile_range(west, south, east, north, z)
    n = 2**z
    x_min = ((west + 180) / 360.0 * n).floor.clamp(0, n - 1)
    x_max = ((east + 180) / 360.0 * n).floor.clamp(0, n - 1)
    y_min = lat_to_tile_y(north, n)
    y_max = lat_to_tile_y(south, n)
    [x_min, x_max, y_min, y_max]
  end

  # Valid for lat in (-85.05, 85.05) — the Web Mercator bounds. Values outside this
  # range produce NaN/Infinity that clamp silently to 0 or n-1.
  def lat_to_tile_y(lat_deg, n)
    lat_rad = lat_deg * Math::PI / 180
    ((1 - Math.log(Math.tan(lat_rad) + 1.0 / Math.cos(lat_rad)) / Math::PI) / 2 * n).floor.clamp(0, n - 1)
  end

  def log(msg, level: :info)
    Rails.logger.public_send(level, msg)
    $stdout.puts msg
    $stdout.flush
  end
end
