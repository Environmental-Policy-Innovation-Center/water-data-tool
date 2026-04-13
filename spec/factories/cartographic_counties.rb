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
