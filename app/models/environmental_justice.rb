class EnvironmentalJustice < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :environmental_justice

  validates :pwsid, presence: true
end
