# == Schema Information
#
# Table name: service_area_geometries
#
#  id          :bigint           not null, primary key
#  centroid    :geometry         point, 4326
#  geom        :geometry         multipolygon, 4326
#  geom_digest :string
#  pwsid       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_service_area_geometries_on_centroid     (centroid) USING gist
#  index_service_area_geometries_on_geom         (geom) USING gist
#  index_service_area_geometries_on_geom_digest  (geom_digest)
#  index_service_area_geometries_on_pwsid        (pwsid) UNIQUE
#
class ServiceAreaGeometry < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :service_area_geometry

  validates :pwsid, presence: true
end
