class AddGeomDigestToServiceAreaGeometries < ActiveRecord::Migration[8.1]
  def change
    add_column :service_area_geometries, :geom_digest, :string
    add_index :service_area_geometries, :geom_digest
  end
end
