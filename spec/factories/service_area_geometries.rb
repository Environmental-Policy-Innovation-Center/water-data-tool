FactoryBot.define do
  factory :service_area_geometry do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    geom { nil }
    centroid { nil }
  end
end
