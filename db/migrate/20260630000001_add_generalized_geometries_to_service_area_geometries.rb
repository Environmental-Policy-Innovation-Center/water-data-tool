class AddGeneralizedGeometriesToServiceAreaGeometries < ActiveRecord::Migration[8.1]
  def change
    add_column :service_area_geometries, :geom_z0_4, :geometry,
      geographic: false, srid: 4326, limit: {type: :multi_polygon}
    add_column :service_area_geometries, :geom_z5, :geometry,
      geographic: false, srid: 4326, limit: {type: :multi_polygon}
    add_column :service_area_geometries, :geom_z6, :geometry,
      geographic: false, srid: 4326, limit: {type: :multi_polygon}
    add_column :service_area_geometries, :geom_z7, :geometry,
      geographic: false, srid: 4326, limit: {type: :multi_polygon}

    add_index :service_area_geometries, :geom_z0_4, using: :gist
    add_index :service_area_geometries, :geom_z5, using: :gist
    add_index :service_area_geometries, :geom_z6, using: :gist
    add_index :service_area_geometries, :geom_z7, using: :gist
  end
end
