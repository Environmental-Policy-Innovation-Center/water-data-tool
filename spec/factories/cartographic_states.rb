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
