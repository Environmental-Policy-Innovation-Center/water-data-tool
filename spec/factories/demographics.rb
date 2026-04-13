FactoryBot.define do
  factory :demographic do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    total_population { 1500 }
    population_density { 120.5 }
    median_household_income { 62000 }
    household_income_lowest_quintile { 28000 }
    poverty_rate { 11.2 }
    population_in_poverty_rate { 10.8 }
    unemployment_rate { 3.4 }
    bachelors_degree_rate { 38.5 }
    no_health_insurance_rate { 6.2 }
    age_under_5_rate { 5.1 }
    age_over_61_rate { 22.3 }
    white_rate { 92.1 }
    black_rate { 1.2 }
    asian_rate { 1.8 }
    aian_rate { 0.4 }
    napi_rate { 0.1 }
    hispanic_rate { 2.3 }
    other_race_rate { 0.5 }
    mixed_race_rate { 1.6 }
    poc_rate { 7.9 }
    renter_rate { 32.4 }
    owner_rate { 67.6 }
    water_rate_under_125 { 15.2 }
    water_rate_125_249 { 28.4 }
    water_rate_250_499 { 34.1 }
    water_rate_500_749 { 14.8 }
    water_rate_750_999 { 5.3 }
    water_rate_over_1000 { 2.2 }
    most_common_rate_tier { "$250–499" }
  end
end
