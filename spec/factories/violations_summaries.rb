# == Schema Information
#
# Table name: violations_summaries
#
#  id                               :bigint           not null, primary key
#  groundwater_rule_10yr            :integer
#  groundwater_rule_5yr             :integer
#  health_violations_10yr           :integer
#  health_violations_5yr            :integer
#  inorganic_chemicals_10yr         :integer
#  inorganic_chemicals_5yr          :integer
#  lead_and_copper_10yr             :integer
#  lead_and_copper_5yr              :integer
#  paperwork_violations_10yr        :integer
#  paperwork_violations_5yr         :integer
#  pwsid                            :string           not null
#  radionuclides_10yr               :integer
#  radionuclides_5yr                :integer
#  stage_1_disinfectants_10yr       :integer
#  stage_1_disinfectants_5yr        :integer
#  stage_2_disinfectants_10yr       :integer
#  stage_2_disinfectants_5yr        :integer
#  surface_water_treatment_10yr     :integer
#  surface_water_treatment_5yr      :integer
#  synthetic_organic_chemicals_10yr :integer
#  synthetic_organic_chemicals_5yr  :integer
#  total_coliform_10yr              :integer
#  total_coliform_5yr               :integer
#  total_violations_10yr            :integer
#  total_violations_5yr             :integer
#  violations_all_years             :integer
#  volatile_organic_chemicals_10yr  :integer
#  volatile_organic_chemicals_5yr   :integer
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#
# Indexes
#
#  index_violations_summaries_on_pwsid  (pwsid) UNIQUE
#
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
