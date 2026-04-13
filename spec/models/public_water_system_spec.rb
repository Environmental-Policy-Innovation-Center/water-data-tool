require "rails_helper"

RSpec.describe PublicWaterSystem, type: :model do
  describe "associations" do
    it { is_expected.to have_one(:service_area_geometry).with_foreign_key("pwsid") }
    it { is_expected.to have_one(:demographic).with_foreign_key("pwsid") }
    it { is_expected.to have_one(:violations_summary).with_foreign_key("pwsid") }
    it { is_expected.to have_one(:environmental_justice).with_foreign_key("pwsid") }
    it { is_expected.to have_one(:funding_summary).with_foreign_key("pwsid") }
    it { is_expected.to have_one(:watershed_hazard).with_foreign_key("pwsid") }
    it { is_expected.to have_one(:boil_water_summary).with_foreign_key("pwsid") }
    it { is_expected.to have_one(:trend_datum).with_foreign_key("pwsid") }
    it { is_expected.to have_many(:place_system_crosswalks).with_foreign_key("pwsid") }
    it { is_expected.to have_many(:cartographic_places).through(:place_system_crosswalks) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:pwsid) }

    it "accepts valid pwsid format" do
      pws = build(:public_water_system, pwsid: "VT0012345")
      expect(pws).to be_valid
    end

    it "rejects lowercase state codes" do
      pws = build(:public_water_system, pwsid: "vt0012345")
      expect(pws).not_to be_valid
    end

    it "rejects pwsid with wrong length" do
      pws = build(:public_water_system, pwsid: "VT123")
      expect(pws).not_to be_valid
    end

    it "rejects digits in place of state code" do
      pws = build(:public_water_system, pwsid: "120012345")
      expect(pws).not_to be_valid
    end

    it "rejects non-digit characters in the numeric portion" do
      pws = build(:public_water_system, pwsid: "VT001234X")
      expect(pws).not_to be_valid
    end
  end
end
