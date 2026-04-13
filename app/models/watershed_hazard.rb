class WatershedHazard < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", inverse_of: :watershed_hazard

  validates :pwsid, presence: true
end
