class CreateEnvironmentalJustices < ActiveRecord::Migration[8.1]
  def change
    create_table :environmental_justices do |t|
      t.string :pwsid, null: false

      # CEJST
      t.decimal :cejst_disadvantaged_pct, precision: 5, scale: 2
      t.integer :cejst_lead_paint_indicator
      t.decimal :cejst_low_life_expectancy_pctl

      # EJScreen
      t.decimal :ejscreen_drinking_water
      t.decimal :ejscreen_disability_rate

      # SVI
      t.decimal :svi_overall_pctl, precision: 5, scale: 2

      # CVI
      t.decimal :cvi_redlining
      t.decimal :cvi_life_expectancy
      t.decimal :cvi_cancer_risk
      t.decimal :cvi_overall_score, precision: 5, scale: 2

      t.timestamps
    end

    add_index :environmental_justices, :pwsid, unique: true
  end
end
