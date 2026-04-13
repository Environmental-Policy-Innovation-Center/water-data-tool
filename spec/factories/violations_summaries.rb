FactoryBot.define do
  factory :violations_summary do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    health_violations_5yr { 0 }
    groundwater_rule_5yr { 0 }
    surface_water_treatment_5yr { 0 }
    lead_and_copper_5yr { 0 }
    radionuclides_5yr { 0 }
    inorganic_chemicals_5yr { 0 }
    synthetic_organic_chemicals_5yr { 0 }
    volatile_organic_chemicals_5yr { 0 }
    total_coliform_5yr { 0 }
    stage_1_disinfectants_5yr { 0 }
    stage_2_disinfectants_5yr { 0 }
    paperwork_violations_5yr { 1 }
    total_violations_5yr { 1 }
    health_violations_10yr { 1 }
    groundwater_rule_10yr { 0 }
    surface_water_treatment_10yr { 0 }
    lead_and_copper_10yr { 1 }
    radionuclides_10yr { 0 }
    inorganic_chemicals_10yr { 0 }
    synthetic_organic_chemicals_10yr { 0 }
    volatile_organic_chemicals_10yr { 0 }
    total_coliform_10yr { 0 }
    stage_1_disinfectants_10yr { 0 }
    stage_2_disinfectants_10yr { 0 }
    paperwork_violations_10yr { 2 }
    total_violations_10yr { 3 }
    violations_all_years { 8 }
  end
end
