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
