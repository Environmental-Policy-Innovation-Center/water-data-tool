# == Schema Information
#
# Table name: cartographic_places
#
#  affgeoid :string
#  geoid    :string(7)
#  geom     :geometry         multipolygon, 4326
#  gid      :integer          not null, primary key
#  name     :string
#  namelsad :string
#  placefp  :string(5)
#  statefp  :string(2)
#  stusps   :string(2)
#
# Indexes
#
#  index_cartographic_places_on_affgeoid  (affgeoid)
#  index_cartographic_places_on_geoid     (geoid)
#  index_cartographic_places_on_geom      (geom) USING gist
#
FactoryBot.define do
  factory :cartographic_place do
    sequence(:gid) { |n| n }
    statefp { "50" }
    placefp { "73600" }
    sequence(:geoid) { |n| "50#{format("%05d", n)}" }
    name { "Montpelier" }
    namelsad { "Montpelier city" }
    stusps { "VT" }
    geom { nil }
  end
end
