class CreateTileCache < ActiveRecord::Migration[8.1]
  def up
    create_table :tile_cache, id: false do |t|
      t.string :layer, null: false
      t.integer :z, null: false
      t.integer :x, null: false
      t.integer :y, null: false
      t.binary :mvt
    end

    execute "ALTER TABLE tile_cache ADD PRIMARY KEY (layer, z, x, y)"
    add_index :tile_cache, %i[z x y]
  end

  def down
    drop_table :tile_cache
  end
end
