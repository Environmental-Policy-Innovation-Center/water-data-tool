# == Schema Information
#
# Table name: place_system_crosswalks
#
#  id                       :bigint           not null, primary key
#  fraction_of_place        :decimal(, )
#  fraction_of_service_area :decimal(, )
#  geoid                    :string(7)        not null
#  pwsid                    :string           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_place_system_crosswalks_on_geoid_and_pwsid  (geoid,pwsid) UNIQUE
#  index_place_system_crosswalks_on_pwsid            (pwsid)
#
class PlaceSystemCrosswalk < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid"
  belongs_to :cartographic_place, foreign_key: "geoid", primary_key: "geoid"

  validates :pwsid, presence: true
  validates :geoid, presence: true
end
