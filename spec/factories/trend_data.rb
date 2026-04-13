# == Schema Information
#
# Table name: trend_data
#
#  id                               :bigint           not null, primary key
#  households_pct_change            :decimal(, )
#  income_change_flag               :string
#  lowest_quintile_pct_change       :decimal(, )
#  mhi_pct_change                   :decimal(, )
#  mhi_pct_change_capped            :decimal(, )
#  poc_pct_change                   :decimal(, )
#  population_change_flag           :string
#  population_in_poverty_pct_change :decimal(, )
#  population_pct_change            :decimal(, )
#  population_pct_change_capped     :decimal(, )
#  poverty_pct_change               :decimal(, )
#  pwsid                            :string           not null
#  unemployment_pct_change          :decimal(, )
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#
# Indexes
#
#  index_trend_data_on_pwsid  (pwsid) UNIQUE
#
FactoryBot.define do
  factory :trend_datum do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    population_pct_change { 4.2 }
    unemployment_pct_change { -1.8 }
    mhi_pct_change { 12.5 }
    lowest_quintile_pct_change { 8.3 }
    households_pct_change { 3.1 }
    poverty_pct_change { -2.4 }
    poc_pct_change { 6.7 }
    population_in_poverty_pct_change { -1.2 }
    income_change_flag { "Increasing" }
    population_change_flag { "Stable" }
    population_pct_change_capped { 4.2 }
    mhi_pct_change_capped { 12.5 }
  end
end
