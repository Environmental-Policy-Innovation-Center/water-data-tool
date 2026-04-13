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
require "rails_helper"

RSpec.describe TrendDatum, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:public_water_system).with_foreign_key("pwsid") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:pwsid) }
  end
end
