# == Schema Information
#
# Table name: cartographic_states
#
#  geoid   :string(2)
#  geom    :geometry         multipolygon, 4326
#  gid     :integer          not null, primary key
#  name    :string
#  statefp :string(2)
#  stusps  :string(2)
#
# Indexes
#
#  index_cartographic_states_on_geom  (geom) USING gist
#
class CartographicState < ApplicationRecord
  self.primary_key = "gid"

  scope :containing_point, ->(lng:, lat:) {
    where(
      "geom IS NOT NULL AND ST_Intersects(geom, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
      lng,
      lat
    )
  }
end
