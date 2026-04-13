class BoilWaterSummary < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", inverse_of: :boil_water_summary

  validates :pwsid, presence: true
end
