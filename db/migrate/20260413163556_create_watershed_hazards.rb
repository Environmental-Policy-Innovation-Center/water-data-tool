class CreateWatershedHazards < ActiveRecord::Migration[8.1]
  def change
    create_table :watershed_hazards do |t|
      t.string :pwsid, null: false
      t.integer :num_facilities
      t.integer :npdes_permits
      t.integer :permit_effluent_violations
      t.integer :open_underground_storage_tanks
      t.integer :risk_management_plan_facilities
      t.integer :impaired_streams_303d

      t.timestamps
    end

    add_index :watershed_hazards, :pwsid, unique: true
  end
end
