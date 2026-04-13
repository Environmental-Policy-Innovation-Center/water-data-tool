class CreatePlaceSystemCrosswalks < ActiveRecord::Migration[8.1]
  def change
    create_table :place_system_crosswalks do |t|
      t.string :geoid, limit: 7, null: false
      t.string :pwsid, null: false
      t.decimal :fraction_of_service_area
      t.decimal :fraction_of_place

      t.timestamps
    end

    add_index :place_system_crosswalks, %i[geoid pwsid]
    add_index :place_system_crosswalks, :pwsid
  end
end
