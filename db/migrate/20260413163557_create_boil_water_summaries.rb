class CreateBoilWaterSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :boil_water_summaries do |t|
      t.string :pwsid, null: false
      # Date fields kept as strings intentionally — BWN date formats vary widely
      # by state (some report full dates, others only years). Parsing to date
      # would require per-state format handling and would lose original values.
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
