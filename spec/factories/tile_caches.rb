FactoryBot.define do
  factory :tile_cache do
    layer { "pws" }
    sequence(:z) { |n| n % 13 }
    sequence(:x) { |n| n }
    sequence(:y) { |n| n }
    mvt { nil }
  end
end
