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
  end

  describe ".apply_filters" do
    let!(:groundwater_system) { create(:public_water_system, gw_sw_code: "Groundwater", stusps: "VT") }
    let!(:surface_water_system) { create(:public_water_system, gw_sw_code: "Surface Water", stusps: "RI") }

    context "categorical filters" do
      it "filters by gw_sw_code" do
        results = described_class.apply_filters(gw_sw_code: "Groundwater")
        expect(results).to include(groundwater_system)
        expect(results).not_to include(surface_water_system)
      end

      it "filters by state" do
        results = described_class.apply_filters(state: "VT")
        expect(results).to include(groundwater_system)
        expect(results).not_to include(surface_water_system)
      end

      it "filters by multiple owner_types (OR within group)" do
        federal = create(:public_water_system, owner_type: "Federal")
        local = create(:public_water_system, owner_type: "Local")
        private_sys = create(:public_water_system, owner_type: "Private")

        results = described_class.apply_filters(owner_type: %w[Federal Local])
        expect(results).to include(federal, local)
        expect(results).not_to include(private_sys)
      end

      it "ANDs between different filter groups" do
        results = described_class.apply_filters(gw_sw_code: "Groundwater", state: "RI")
        expect(results).to be_empty
      end
    end

    context "boolean filters" do
      it "filters wholesalers" do
        wholesaler = create(:public_water_system, is_wholesaler: true)
        non_wholesaler = create(:public_water_system, is_wholesaler: false)

        results = described_class.apply_filters(is_wholesaler: "true")
        expect(results).to include(wholesaler)
        expect(results).not_to include(non_wholesaler)
      end

      it "filters systems with open violations" do
        with_viol = create(:public_water_system, open_health_viol: "Yes")
        without_viol = create(:public_water_system, open_health_viol: "No")

        results = described_class.apply_filters(has_open_violations: "true")
        expect(results).to include(with_viol)
        expect(results).not_to include(without_viol)
      end
    end

    context "range filters" do
      it "filters by area_min" do
        small = create(:public_water_system, area_sq_miles: 5.0)
        large = create(:public_water_system, area_sq_miles: 50.0)

        results = described_class.apply_filters(area_min: "20")
        expect(results).to include(large)
        expect(results).not_to include(small)
      end

      it "filters by area_max" do
        small = create(:public_water_system, area_sq_miles: 5.0)
        large = create(:public_water_system, area_sq_miles: 50.0)

        results = described_class.apply_filters(area_max: "10")
        expect(results).to include(small)
        expect(results).not_to include(large)
      end

      it "filters by area range (min AND max)" do
        small = create(:public_water_system, area_sq_miles: 2.0)
        medium = create(:public_water_system, area_sq_miles: 15.0)
        large = create(:public_water_system, area_sq_miles: 80.0)

        results = described_class.apply_filters(area_min: "10", area_max: "20")
        expect(results).to include(medium)
        expect(results).not_to include(small, large)
      end
    end

    context "join-based filters (violations)" do
      it "filters by health_violations_5yr_min" do
        clean = create(:public_water_system)
        dirty = create(:public_water_system)
        create(:violations_summary, public_water_system: clean, health_violations_5yr: 0)
        create(:violations_summary, public_water_system: dirty, health_violations_5yr: 5)

        results = described_class.apply_filters(health_violations_5yr_min: "3")
        expect(results).to include(dirty)
        expect(results).not_to include(clean)
      end
    end

    context "join-based filters (demographics)" do
      it "filters by poverty_rate_min" do
        low_poverty = create(:public_water_system)
        high_poverty = create(:public_water_system)
        create(:demographic, public_water_system: low_poverty, poverty_rate: 5.0)
        create(:demographic, public_water_system: high_poverty, poverty_rate: 25.0)

        results = described_class.apply_filters(poverty_rate_min: "20")
        expect(results).to include(high_poverty)
        expect(results).not_to include(low_poverty)
      end
    end

    context "geographic filters" do
      it "filters by place_geoid via crosswalk" do
        place = create(:cartographic_place)
        in_place = create(:public_water_system)
        out_of_place = create(:public_water_system)
        create(:place_system_crosswalk, public_water_system: in_place, cartographic_place: place,
          pwsid: in_place.pwsid, geoid: place.geoid)

        results = described_class.apply_filters(place_geoid: place.geoid)
        expect(results).to include(in_place)
        expect(results).not_to include(out_of_place)
      end
    end

    context "with no filters" do
      it "returns all systems" do
        results = described_class.apply_filters({})
        expect(results).to include(groundwater_system, surface_water_system)
      end
    end
  end
end
