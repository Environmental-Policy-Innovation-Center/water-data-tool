class CreateTrendData < ActiveRecord::Migration[8.1]
  def change
    create_table :trend_data do |t|
      t.string :pwsid, null: false
      t.decimal :population_pct_change
      t.decimal :unemployment_pct_change
      t.decimal :mhi_pct_change
      t.decimal :lowest_quintile_pct_change
      t.decimal :households_pct_change
      t.decimal :poverty_pct_change
      t.decimal :poc_pct_change
      t.decimal :population_in_poverty_pct_change
      t.string :income_change_flag
      t.string :population_change_flag
      t.decimal :population_pct_change_capped
      t.decimal :mhi_pct_change_capped

      t.timestamps
    end

    add_index :trend_data, :pwsid, unique: true
  end
end
