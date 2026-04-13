class CreateDemographics < ActiveRecord::Migration[8.1]
  def change
    create_table :demographics do |t|
      t.string :pwsid, null: false
      t.integer :total_population
      t.decimal :population_density
      t.integer :median_household_income
      t.integer :household_income_lowest_quintile
      t.decimal :poverty_rate, precision: 5, scale: 2
      t.decimal :population_in_poverty_rate, precision: 5, scale: 2
      t.decimal :unemployment_rate, precision: 5, scale: 2
      t.decimal :bachelors_degree_rate, precision: 5, scale: 2
      t.decimal :no_health_insurance_rate, precision: 5, scale: 2
      t.decimal :age_under_5_rate, precision: 5, scale: 2
      t.decimal :age_over_61_rate, precision: 5, scale: 2
      t.decimal :white_rate, precision: 5, scale: 2
      t.decimal :black_rate, precision: 5, scale: 2
      t.decimal :asian_rate, precision: 5, scale: 2
      t.decimal :aian_rate, precision: 5, scale: 2
      t.decimal :napi_rate, precision: 5, scale: 2
      t.decimal :hispanic_rate, precision: 5, scale: 2
      t.decimal :other_race_rate, precision: 5, scale: 2
      t.decimal :mixed_race_rate, precision: 5, scale: 2
      t.decimal :poc_rate, precision: 5, scale: 2
      t.decimal :renter_rate, precision: 5, scale: 2
      t.decimal :owner_rate, precision: 5, scale: 2
      t.decimal :water_rate_under_125, precision: 5, scale: 2
      t.decimal :water_rate_125_249, precision: 5, scale: 2
      t.decimal :water_rate_250_499, precision: 5, scale: 2
      t.decimal :water_rate_500_749, precision: 5, scale: 2
      t.decimal :water_rate_750_999, precision: 5, scale: 2
      t.decimal :water_rate_over_1000, precision: 5, scale: 2
      t.string :most_common_rate_tier

      t.timestamps
    end

    add_index :demographics, :pwsid, unique: true
  end
end
