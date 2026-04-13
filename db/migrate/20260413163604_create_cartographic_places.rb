class CreateCartographicPlaces < ActiveRecord::Migration[8.1]
  def up
    create_table :cartographic_places, id: false do |t|
      t.integer :gid, null: false
      t.string :statefp, limit: 2
      t.string :placefp, limit: 5
      t.string :geoid, limit: 7
      t.string :name
      t.string :namelsad
      t.string :stusps, limit: 2
      t.string :affgeoid
      t.column :geom, :geometry, geographic: false, srid: 4326, limit: {type: :multi_polygon}
    end

    execute "ALTER TABLE cartographic_places ADD PRIMARY KEY (gid)"
    add_index :cartographic_places, :geom, using: :gist
    add_index :cartographic_places, :geoid
    add_index :cartographic_places, :affgeoid
  end

  def down
    drop_table :cartographic_places
  end
end
