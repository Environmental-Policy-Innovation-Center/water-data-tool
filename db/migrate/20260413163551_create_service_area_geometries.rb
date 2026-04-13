class CreateServiceAreaGeometries < ActiveRecord::Migration[8.1]
  def change
    create_table :service_area_geometries do |t|
      t.string :pwsid, null: false
      t.column :geom, :geometry, geographic: false, srid: 4326, limit: { type: :multi_polygon }
      t.column :centroid, :geometry, geographic: false, srid: 4326, limit: { type: :point }

      t.timestamps
    end

    add_index :service_area_geometries, :pwsid, unique: true
    add_index :service_area_geometries, :geom, using: :gist
    add_index :service_area_geometries, :centroid, using: :gist
  end
end
