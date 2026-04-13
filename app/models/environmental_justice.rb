# == Schema Information
#
# Table name: environmental_justices
#
#  id                             :bigint           not null, primary key
#  cejst_disadvantaged_pct        :decimal(5, 2)
#  cejst_lead_paint_indicator     :integer
#  cejst_low_life_expectancy_pctl :decimal(, )
#  cvi_cancer_risk                :decimal(, )
#  cvi_life_expectancy            :decimal(, )
#  cvi_overall_score              :decimal(5, 2)
#  cvi_redlining                  :decimal(, )
#  ejscreen_disability_rate       :decimal(, )
#  ejscreen_drinking_water        :decimal(, )
#  pwsid                          :string           not null
#  svi_overall_pctl               :decimal(5, 2)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#
# Indexes
#
#  index_environmental_justices_on_pwsid  (pwsid) UNIQUE
#
class EnvironmentalJustice < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :environmental_justice

  validates :pwsid, presence: true
end
