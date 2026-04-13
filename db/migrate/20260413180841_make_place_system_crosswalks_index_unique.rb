class MakePlaceSystemCrosswalksIndexUnique < ActiveRecord::Migration[8.1]
  def change
    remove_index :place_system_crosswalks, %i[geoid pwsid]
    add_index :place_system_crosswalks, %i[geoid pwsid], unique: true
  end
end
