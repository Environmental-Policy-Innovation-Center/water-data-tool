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
FactoryBot.define do
  factory :place_system_crosswalk do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    association :cartographic_place
    geoid { cartographic_place.geoid }
    fraction_of_service_area { 0.75 }
    fraction_of_place { 0.30 }
  end
end
