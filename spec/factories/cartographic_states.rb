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
FactoryBot.define do
  factory :cartographic_state do
    sequence(:gid) { |n| n }
    statefp { "50" }
    stusps { "VT" }
    name { "Vermont" }
    geoid { "50" }
    geom { nil }
  end
end
