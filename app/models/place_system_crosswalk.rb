class PlaceSystemCrosswalk < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid"
  belongs_to :cartographic_place, foreign_key: "geoid", primary_key: "geoid"

  validates :pwsid, presence: true
  validates :geoid, presence: true
end
