class CreateBoilWaterSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :boil_water_summaries do |t|
      t.string :pwsid, null: false
      t.string :first_advisory_date
      t.string :last_advisory_date
      t.integer :total_notices
      t.string :state_reporting_year_min
      t.string :state_reporting_year_max
      t.string :state
      t.text :tooltip_text
      t.string :download_url
      t.string :date_range_display

      t.timestamps
    end

    add_index :boil_water_summaries, :pwsid, unique: true
  end
end
