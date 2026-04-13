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
FactoryBot.define do
  factory :tile_cache do
    layer { "pws" }
    sequence(:z) { |n| n % 13 }
    sequence(:x) { |n| n }
    sequence(:y) { |n| n }
    mvt { nil }
  end
end
