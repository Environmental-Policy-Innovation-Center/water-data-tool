FactoryBot.define do
  factory :place_system_crosswalk do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    association :cartographic_place
    geoid { cartographic_place.geoid }
    fraction_of_service_area { 0.75 }
    fraction_of_place { 0.30 }
  end
end
