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

RSpec.describe PublicWaterSystemSerializer do
  subject(:result) { described_class.new(pws).serialize }

  let(:pws) { build(:public_water_system) }

  describe "#serialize" do
    it "returns a hash" do
      expect(result).to be_a(Hash)
    end

    it "includes all expected index fields" do
      expect(result.keys).to match_array(%i[
        pwsid pws_name stusps primacy_agency pop_cat_5
        population_served_count service_connections_count gw_sw_code
        owner_type primacy_type service_area_type area_sq_miles
        open_health_viol is_wholesaler is_school_or_daycare counties
      ])
    end

    it "maps values correctly from the model" do
      expect(result[:pwsid]).to eq(pws.pwsid)
      expect(result[:pws_name]).to eq(pws.pws_name)
      expect(result[:stusps]).to eq(pws.stusps)
      expect(result[:primacy_agency]).to eq(pws.primacy_agency)
      expect(result[:pop_cat_5]).to eq(pws.pop_cat_5)
      expect(result[:population_served_count]).to eq(pws.population_served_count)
      expect(result[:service_connections_count]).to eq(pws.service_connections_count)
      expect(result[:gw_sw_code]).to eq(pws.gw_sw_code)
      expect(result[:owner_type]).to eq(pws.owner_type)
      expect(result[:primacy_type]).to eq(pws.primacy_type)
      expect(result[:service_area_type]).to eq(pws.service_area_type)
      expect(result[:area_sq_miles]).to eq(pws.area_sq_miles)
      expect(result[:open_health_viol]).to eq(pws.open_health_viol)
      expect(result[:is_wholesaler]).to eq(pws.is_wholesaler)
      expect(result[:is_school_or_daycare]).to eq(pws.is_school_or_daycare)
      expect(result[:counties]).to eq(pws.counties)
    end

    context "when optional fields are nil" do
      let(:pws) do
        build(:public_water_system,
          primacy_agency: nil,
          counties: nil,
          area_sq_miles: nil)
      end

      it "returns nil for missing primacy_agency" do
        expect(result[:primacy_agency]).to be_nil
      end

      it "returns nil for missing counties" do
        expect(result[:counties]).to be_nil
      end

      it "returns nil for missing area_sq_miles" do
        expect(result[:area_sq_miles]).to be_nil
      end
    end

    it "does not include association sub-objects" do
      expect(result).not_to have_key(:demographic)
      expect(result).not_to have_key(:violations_summary)
      expect(result).not_to have_key(:environmental_justice)
      expect(result).not_to have_key(:funding_summary)
      expect(result).not_to have_key(:watershed_hazard)
      expect(result).not_to have_key(:boil_water_summary)
      expect(result).not_to have_key(:trend_datum)
    end

    it "does not include internal Rails fields" do
      expect(result).not_to have_key(:created_at)
      expect(result).not_to have_key(:updated_at)
    end
  end
end
