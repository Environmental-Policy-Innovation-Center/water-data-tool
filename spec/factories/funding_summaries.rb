FactoryBot.define do
  factory :funding_summary do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    times_funded { 2 }
    total_srf_assistance { 850_000.00 }
    median_srf_assistance { 425_000.00 }
    total_principal_forgiveness { 200_000.00 }
  end
end
