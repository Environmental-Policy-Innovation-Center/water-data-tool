# == Schema Information
#
# Table name: watershed_hazards
#
#  id                              :bigint           not null, primary key
#  impaired_streams_303d           :integer
#  npdes_permits                   :integer
#  num_facilities                  :integer
#  open_underground_storage_tanks  :integer
#  permit_effluent_violations      :integer
#  pwsid                           :string           not null
#  risk_management_plan_facilities :integer
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#
# Indexes
#
#  index_watershed_hazards_on_pwsid  (pwsid) UNIQUE
#
class WatershedHazard < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :watershed_hazard

  validates :pwsid, presence: true
end
