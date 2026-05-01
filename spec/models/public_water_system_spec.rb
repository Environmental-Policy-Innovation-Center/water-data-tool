# == Schema Information
#
# Table name: public_water_systems
#
#  area_sq_miles                :decimal(, )
#  counties                     :text
#  detailed_facility_report     :string
#  ewg_report_link              :string
#  first_reported_date          :string
#  gw_sw_code                   :string
#  is_grant_eligible            :boolean
#  is_school_or_daycare         :boolean
#  is_wholesaler                :boolean
#  open_health_viol             :string
#  owner_type                   :string
#  phone_number                 :string
#  pop_cat_5                    :string
#  population_served_count      :integer
#  primacy_agency               :string
#  primacy_type                 :string
#  primary_source_code          :string
#  pws_name                     :string
#  pwsid                        :string           not null, primary key
#  service_area_type            :string
#  service_connections_count    :integer
#  source_water_protection_code :string
#  stusps                       :string(2)
#  symbology_field              :string
#  years_operating              :integer
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
# Indexes
#
#  index_public_water_systems_on_gw_sw_code    (gw_sw_code)
#  index_public_water_systems_on_owner_type    (owner_type)
#  index_public_water_systems_on_pop_cat_5     (pop_cat_5)
#  index_public_water_systems_on_primacy_type  (primacy_type)
#  index_public_water_systems_on_stusps        (stusps)
#
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

  describe "scopes" do
    describe ".with_details" do
      it "eager loads all detail associations" do
        pws = create(:public_water_system)
        result = PublicWaterSystem.with_details.find_by(pwsid: pws.pwsid)

        expect(result.association(:demographic)).to be_loaded
        expect(result.association(:violations_summary)).to be_loaded
        expect(result.association(:environmental_justice)).to be_loaded
        expect(result.association(:funding_summary)).to be_loaded
        expect(result.association(:watershed_hazard)).to be_loaded
        expect(result.association(:boil_water_summary)).to be_loaded
        expect(result.association(:trend_datum)).to be_loaded
        expect(result.association(:service_area_geometry)).to be_loaded
      end
    end
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

  describe "attribute aliases" do
    it "aliases area to area_sq_miles" do
      pws = create(:public_water_system, area_sq_miles: 12.34)
      expect(pws.area).to eq(12.34)
    end

    it "aliases counties_served to counties" do
      pws = create(:public_water_system, counties: "County A, County B")
      expect(pws.counties_served).to eq("County A, County B")
    end
    it "aliases name to pws_name" do
      pws = create(:public_water_system, pws_name: "Test PWS")
      expect(pws.name).to eq("Test PWS")
    end

    it "aliases population_served to population_served_count" do
      pws = create(:public_water_system, population_served_count: 1_000)
      expect(pws.population_served).to eq(1_000)
    end

    it "aliases report_link to detailed_facility_report" do
      pws = create(:public_water_system, detailed_facility_report: "http://example.com/report")
      expect(pws.report_link).to eq("http://example.com/report")
    end

    it "aliases source_protection to source_water_protection_code" do
      pws = create(:public_water_system, source_water_protection_code: "SPC123")
      expect(pws.source_protection).to eq("SPC123")
    end
  end

  describe ".build_summary" do
    it "returns the expected keys" do
      create(:public_water_system)
      result = PublicWaterSystem.build_summary(PublicWaterSystem.all)

      expect(result.keys).to match_array(%i[
        systems_count total_population_served
        systems_with_open_violations avg_median_household_income
      ])
    end

    it "counts systems in the given scope" do
      create_list(:public_water_system, 3)
      result = PublicWaterSystem.build_summary(PublicWaterSystem.all)

      expect(result[:systems_count]).to eq(3)
    end

    it "sums population from the given scope" do
      create(:public_water_system, population_served_count: 1_000)
      create(:public_water_system, population_served_count: 2_000)
      result = PublicWaterSystem.build_summary(PublicWaterSystem.all)

      expect(result[:total_population_served]).to eq(3_000)
    end

    it "counts only systems with open health violations" do
      create(:public_water_system, open_health_viol: "Yes")
      create(:public_water_system, open_health_viol: "No")
      result = PublicWaterSystem.build_summary(PublicWaterSystem.all)

      expect(result[:systems_with_open_violations]).to eq(1)
    end

    it "averages median household income across demographics in scope" do
      pws1 = create(:public_water_system)
      create(:demographic, public_water_system: pws1, pwsid: pws1.pwsid, median_household_income: 60_000)
      pws2 = create(:public_water_system)
      create(:demographic, public_water_system: pws2, pwsid: pws2.pwsid, median_household_income: 80_000)

      result = PublicWaterSystem.build_summary(PublicWaterSystem.all)

      expect(result[:avg_median_household_income]).to eq(70_000)
    end

    it "returns nil for avg_median_household_income when no demographics exist" do
      create(:public_water_system)
      result = PublicWaterSystem.build_summary(PublicWaterSystem.all)

      expect(result[:avg_median_household_income]).to be_nil
    end

    it "respects scope boundaries" do
      create(:public_water_system, stusps: "VT", population_served_count: 500)
      create(:public_water_system, stusps: "OH", population_served_count: 999)

      result = PublicWaterSystem.build_summary(PublicWaterSystem.where(stusps: "VT"))

      expect(result[:systems_count]).to eq(1)
      expect(result[:total_population_served]).to eq(500)
    end
  end
end
