class CreatePublicWaterSystems < ActiveRecord::Migration[8.1]
  def change
    create_table :public_water_systems, id: false, force: :cascade do |t|
      t.string :pwsid, null: false, primary_key: true
      t.string :pws_name
      t.string :stusps, limit: 2
      t.string :primacy_agency
      t.string :pop_cat_5
      t.integer :population_served_count
      t.integer :service_connections_count
      t.string :service_area_type
      t.string :symbology_field
      t.string :gw_sw_code
      t.string :primary_source_code
      t.string :owner_type
      t.string :primacy_type
      t.integer :years_operating
      t.string :first_reported_date
      t.boolean :is_wholesaler
      t.boolean :is_school_or_daycare
      t.boolean :is_grant_eligible
      t.string :source_water_protection_code
      t.string :open_health_viol
      t.string :phone_number
      t.string :detailed_facility_report
      t.string :ewg_report_link
      t.decimal :area_sq_miles
      t.text :counties

      t.timestamps
    end

    add_index :public_water_systems, :stusps
    add_index :public_water_systems, :gw_sw_code
    add_index :public_water_systems, :owner_type
    add_index :public_water_systems, :primacy_type
    add_index :public_water_systems, :pop_cat_5
  end
end
