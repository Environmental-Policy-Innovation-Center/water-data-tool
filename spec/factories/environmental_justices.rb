FactoryBot.define do
  factory :environmental_justice do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    cejst_disadvantaged_pct { 42.50 }
    cejst_lead_paint_indicator { 1 }
    cejst_low_life_expectancy_pctl { 55.3 }
    ejscreen_drinking_water { 68.1 }
    ejscreen_disability_rate { 14.2 }
    svi_overall_pctl { 38.75 }
    cvi_redlining { 2.1 }
    cvi_life_expectancy { 1.8 }
    cvi_cancer_risk { 0.9 }
    cvi_overall_score { 52.00 }
  end
end
