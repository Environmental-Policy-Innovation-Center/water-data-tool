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
FactoryBot.define do
  factory :watershed_hazard do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    num_facilities { 1 }
    npdes_permits { 3 }
    permit_effluent_violations { 0 }
    open_underground_storage_tanks { 2 }
    risk_management_plan_facilities { 1 }
    impaired_streams_303d { 0 }
  end
end
