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
