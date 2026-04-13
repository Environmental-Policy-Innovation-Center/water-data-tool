class CreateViolationsSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :violations_summaries do |t|
      t.string :pwsid, null: false

      # 5-year health violations
      t.integer :health_violations_5yr
      t.integer :groundwater_rule_5yr
      t.integer :surface_water_treatment_5yr
      t.integer :lead_and_copper_5yr
      t.integer :radionuclides_5yr
      t.integer :inorganic_chemicals_5yr
      t.integer :synthetic_organic_chemicals_5yr
      t.integer :volatile_organic_chemicals_5yr
      t.integer :total_coliform_5yr
      t.integer :stage_1_disinfectants_5yr
      t.integer :stage_2_disinfectants_5yr
      t.integer :paperwork_violations_5yr
      t.integer :total_violations_5yr

      # 10-year health violations
      t.integer :health_violations_10yr
      t.integer :groundwater_rule_10yr
      t.integer :surface_water_treatment_10yr
      t.integer :lead_and_copper_10yr
      t.integer :radionuclides_10yr
      t.integer :inorganic_chemicals_10yr
      t.integer :synthetic_organic_chemicals_10yr
      t.integer :volatile_organic_chemicals_10yr
      t.integer :total_coliform_10yr
      t.integer :stage_1_disinfectants_10yr
      t.integer :stage_2_disinfectants_10yr
      t.integer :paperwork_violations_10yr
      t.integer :total_violations_10yr

      # All-time
      t.integer :violations_all_years

      t.timestamps
    end

    add_index :violations_summaries, :pwsid, unique: true
  end
end
