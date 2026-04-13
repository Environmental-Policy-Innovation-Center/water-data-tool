class CreateCartographicCounties < ActiveRecord::Migration[8.1]
  def up
    create_table :cartographic_counties, id: false do |t|
      t.integer :gid, null: false
      t.string :statefp, limit: 2
      t.string :countyfp, limit: 3
      t.string :geoid, limit: 5
      t.string :name
      t.string :namelsad
      t.string :stusps, limit: 2
      t.column :geom, :geometry, geographic: false, srid: 4326, limit: { type: :multi_polygon }
    end

    execute "ALTER TABLE cartographic_counties ADD PRIMARY KEY (gid)"
    add_index :cartographic_counties, :geom, using: :gist
    add_index :cartographic_counties, %i[namelsad stusps]
  end

  def down
    drop_table :cartographic_counties
  end
end
