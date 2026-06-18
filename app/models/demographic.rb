# == Schema Information
#
# Table name: demographics
#
#  id                               :bigint           not null, primary key
#  age_over_61_rate                 :decimal(5, 2)
#  age_under_5_rate                 :decimal(5, 2)
#  aian_rate                        :decimal(5, 2)
#  asian_rate                       :decimal(5, 2)
#  bachelors_degree_rate            :decimal(5, 2)
#  black_rate                       :decimal(5, 2)
#  hispanic_rate                    :decimal(5, 2)
#  household_income_lowest_quintile :integer
#  median_household_income          :integer
#  mixed_race_rate                  :decimal(5, 2)
#  most_common_rate_tier            :string
#  napi_rate                        :decimal(5, 2)
#  no_health_insurance_rate         :decimal(5, 2)
#  other_race_rate                  :decimal(5, 2)
#  owner_rate                       :decimal(5, 2)
#  poc_rate                         :decimal(5, 2)
#  population_density               :decimal(, )
#  population_in_poverty_rate       :decimal(5, 2)
#  poverty_rate                     :decimal(5, 2)
#  pwsid                            :string           not null
#  renter_rate                      :decimal(5, 2)
#  total_population                 :integer
#  unemployment_rate                :decimal(5, 2)
#  water_rate_125_249               :decimal(5, 2)
#  water_rate_250_499               :decimal(5, 2)
#  water_rate_500_749               :decimal(5, 2)
#  water_rate_750_999               :decimal(5, 2)
#  water_rate_over_1000             :decimal(5, 2)
#  water_rate_under_125             :decimal(5, 2)
#  white_rate                       :decimal(5, 2)
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#
# Indexes
#
#  index_demographics_on_pwsid  (pwsid) UNIQUE
#
class Demographic < ApplicationRecord
  include Histogrammable

  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :demographic

  validates :pwsid, presence: true

  enum :most_common_rate_tier, {
    under_125: "Most people pay < $125 for water & sewer annually",
    tier_125_249: "Most people pay between $125-249 for water & sewer annually",
    tier_250_499: "Most people pay between $250-499 for water & sewer annually",
    tier_500_749: "Most people pay between $500-749 for water & sewer annually",
    tier_750_999: "Most people pay between $750-999 for water & sewer annually",
    over_1000: "Most people pay > $1000 for water & sewer annually",
    no_information: "No Information on annual water & sewer rates"
  }
end
