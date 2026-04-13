FactoryBot.define do
  factory :boil_water_summary do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    first_advisory_date { "2018-06-15" }
    last_advisory_date { "2021-09-03" }
    total_notices { 3 }
    state_reporting_year_min { "2015" }
    state_reporting_year_max { "2023" }
    state { "Vermont" }
    tooltip_text { "Vermont has reported boil water notices since 2015." }
    download_url { "https://example.com/vt-bwn.csv" }
    date_range_display { "2015–2023" }
  end
end
