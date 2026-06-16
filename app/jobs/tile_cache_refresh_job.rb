class TileCacheRefreshJob < ApplicationJob
  queue_as :tile_refresh

  def perform(layer:, z:, coords:)
    coords.each do |x, y|
      TileGenerator.generate_tile!(layer, z, x, y)
    end
  end
end
