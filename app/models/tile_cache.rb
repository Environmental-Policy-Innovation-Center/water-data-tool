# == Schema Information
#
# Table name: tile_cache
#
#  layer :string           not null, primary key
#  mvt   :binary
#  x     :integer          not null, primary key
#  y     :integer          not null, primary key
#  z     :integer          not null, primary key
#
# Indexes
#
#  index_tile_cache_on_z_and_x_and_y  (z,x,y)
#
class TileCache < ApplicationRecord
  self.table_name = "tile_cache"
  self.primary_key = [:layer, :z, :x, :y]

  validates :layer, presence: true
  validates :z, presence: true
  validates :x, presence: true
  validates :y, presence: true
end
