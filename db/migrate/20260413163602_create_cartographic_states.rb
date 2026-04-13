class CreateCartographicStates < ActiveRecord::Migration[8.1]
  def up
    create_table :cartographic_states, id: false do |t|
      t.integer :gid, null: false
      t.string :statefp, limit: 2
      t.string :stusps, limit: 2
      t.string :name
      t.string :geoid, limit: 2
      t.column :geom, :geometry, geographic: false, srid: 4326, limit: {type: :multi_polygon}
    end

    execute "ALTER TABLE cartographic_states ADD PRIMARY KEY (gid)"
    add_index :cartographic_states, :geom, using: :gist
  end

  def down
    drop_table :cartographic_states
  end
end
