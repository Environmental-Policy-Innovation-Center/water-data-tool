# == Schema Information
#
# Table name: boil_water_summaries
#
#  id                       :bigint           not null, primary key
#  date_range_display       :string
#  download_url             :string
#  first_advisory_date      :string
#  last_advisory_date       :string
#  pwsid                    :string           not null
#  state                    :string
#  state_reporting_year_max :string
#  state_reporting_year_min :string
#  tooltip_text             :text
#  total_notices            :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_boil_water_summaries_on_pwsid  (pwsid) UNIQUE
#
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
