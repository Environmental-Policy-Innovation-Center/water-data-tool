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
class CartographicPlace < ApplicationRecord
  self.primary_key = "gid"

  has_many :place_system_crosswalks, foreign_key: "geoid", primary_key: "geoid"
  has_many :public_water_systems, through: :place_system_crosswalks
end
