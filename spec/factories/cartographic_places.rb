FactoryBot.define do
  factory :cartographic_place do
    sequence(:gid) { |n| n }
    statefp { "50" }
    placefp { "73600" }
    sequence(:geoid) { |n| "50#{format('%05d', n)}" }
    name { "Montpelier" }
    namelsad { "Montpelier city" }
    stusps { "VT" }
    geom { nil }
  end
end
