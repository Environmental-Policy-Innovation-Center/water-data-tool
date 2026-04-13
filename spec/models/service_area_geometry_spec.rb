# == Schema Information
#
# Table name: service_area_geometries
#
#  id         :bigint           not null, primary key
#  centroid   :geometry         point, 4326
#  geom       :geometry         multipolygon, 4326
#  pwsid      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_service_area_geometries_on_centroid  (centroid) USING gist
#  index_service_area_geometries_on_geom      (geom) USING gist
#  index_service_area_geometries_on_pwsid     (pwsid) UNIQUE
#
require "rails_helper"

RSpec.describe ServiceAreaGeometry, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:public_water_system).with_foreign_key("pwsid") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:pwsid) }
  end
end
