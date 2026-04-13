# == Schema Information
#
# Table name: cartographic_places
#
#  affgeoid :string
#  geoid    :string(7)
#  geom     :geometry         multipolygon, 4326
#  gid      :integer          not null, primary key
#  name     :string
#  namelsad :string
#  placefp  :string(5)
#  statefp  :string(2)
#  stusps   :string(2)
#
# Indexes
#
#  index_cartographic_places_on_affgeoid  (affgeoid)
#  index_cartographic_places_on_geoid     (geoid)
#  index_cartographic_places_on_geom      (geom) USING gist
#
require "rails_helper"

RSpec.describe CartographicPlace, type: :model do
  it "is valid with required fields" do
    place = build(:cartographic_place)
    expect(place).to be_valid
  end
end
