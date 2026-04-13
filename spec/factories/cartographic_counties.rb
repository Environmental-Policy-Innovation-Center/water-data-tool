# == Schema Information
#
# Table name: cartographic_counties
#
#  countyfp :string(3)
#  geoid    :string(5)
#  geom     :geometry         multipolygon, 4326
#  gid      :integer          not null, primary key
#  name     :string
#  namelsad :string
#  statefp  :string(2)
#  stusps   :string(2)
#
# Indexes
#
#  index_cartographic_counties_on_geom                 (geom) USING gist
#  index_cartographic_counties_on_namelsad_and_stusps  (namelsad,stusps)
#
FactoryBot.define do
  factory :cartographic_county do
    sequence(:gid) { |n| n }
    statefp { "50" }
    countyfp { "023" }
    geoid { "50023" }
    name { "Washington" }
    namelsad { "Washington County" }
    stusps { "VT" }
    geom { nil }
  end
end
