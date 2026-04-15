class TileCacheWarmJob < ApplicationJob
  queue_as :default

  # Pre-generate tiles for zoom levels 0–6. Higher zooms are generated
  # on demand — warming all z0–z8 tiles would be 87k+ coordinates.
  # Each zoom level runs as a separate job so completed levels aren't
  # re-done on retry and individual jobs stay short-lived.
  MAX_WARM_ZOOM = 6

  def perform(zoom_level = nil)
    if zoom_level
      warm_zoom(zoom_level)
    else
      (0..MAX_WARM_ZOOM).each { |z| self.class.perform_later(z) }
    end
  end

  private

  def warm_zoom(z)
    tile_count = 0
    grid_size = 2**z

    grid_size.times do |x|
      grid_size.times do |y|
        TileGenerator.layers.each do |layer|
          TileGenerator.generate_tile!(layer, z, x, y)
        end
        tile_count += 1
      rescue => e
        Rails.logger.error("[TileCacheWarm] z#{z}/#{x}/#{y} failed: #{e.class} — #{e.message}")
      end
    end

    Rails.logger.info("[TileCacheWarm] z#{z}: warmed #{tile_count} tile coordinate(s)")
  end
end
