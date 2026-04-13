class TileCache < ApplicationRecord
  self.table_name = "tile_cache"
  self.primary_key = [ :layer, :z, :x, :y ]

  validates :layer, presence: true
  validates :z, presence: true
  validates :x, presence: true
  validates :y, presence: true
end
