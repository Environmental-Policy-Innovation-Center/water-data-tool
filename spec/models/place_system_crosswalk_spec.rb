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
require "rails_helper"

RSpec.describe PlaceSystemCrosswalk, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:public_water_system).with_foreign_key("pwsid") }
    it { is_expected.to belong_to(:cartographic_place).with_foreign_key("geoid").with_primary_key("geoid") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:pwsid) }
    it { is_expected.to validate_presence_of(:geoid) }
  end
end
