require "rails_helper"

RSpec.describe PublicWaterSystemTableSerializer do
  subject(:serializer) { described_class.new(pws) }

  let(:pws) { create(:public_water_system, pws_name: "Green Mountain Water", open_health_viol: true) }

  describe "#serialize" do
    it "returns a hash" do
      expect(serializer.serialize).to be_a(Hash)
    end

    it "includes core PWS identity fields" do
      result = serializer.serialize

      expect(result[:pws_name]).to eq("Green Mountain Water")
      expect(result[:pwsid]).to eq(pws.pwsid)
      expect(result[:stusps]).to eq(pws.stusps)
      expect(result[:open_health_viol]).to be(true)
    end

    it "includes all expected top-level keys" do
      result = serializer.serialize

      expect(result.keys).to include(
        :pws_name, :pwsid, :stusps, :counties, :gw_sw_code,
        :owner_type, :primacy_type, :symbology_field, :area_sq_miles,
        :open_health_viol, :is_wholesaler, :is_school_or_daycare,
        :health_violations_5yr, :health_violations_10yr,
        :total_notices, :total_population, :poverty_rate,
        :cejst_disadvantaged_pct, :times_funded, :num_facilities
      )
    end

    it "defaults association fields to 0 when associations are nil" do
      result = serializer.serialize

      expect(result[:health_violations_5yr]).to eq(0)
      expect(result[:total_notices]).to eq(0)
      expect(result[:total_population]).to eq(0)
      expect(result[:times_funded]).to eq(0)
      expect(result[:num_facilities]).to eq(0)
    end

    it "returns nil for nullable association fields when associations are absent" do
      result = serializer.serialize

      expect(result[:poverty_rate]).to be_nil
      expect(result[:cejst_disadvantaged_pct]).to be_nil
    end

    it "includes violations_summary data when present" do
      create(:violations_summary, pwsid: pws.pwsid, health_violations_5yr: 3)
      pws.reload

      result = described_class.new(pws).serialize

      expect(result[:health_violations_5yr]).to eq(3)
    end

    it "includes demographic data when present" do
      create(:demographic, public_water_system: pws, pwsid: pws.pwsid, total_population: 42_000, poverty_rate: 12.5)
      pws.reload

      result = described_class.new(pws).serialize

      expect(result[:total_population]).to eq(42_000)
      expect(result[:poverty_rate]).to eq(12.5)
    end
  end
end
