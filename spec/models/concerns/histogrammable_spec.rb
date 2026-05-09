require "rails_helper"

RSpec.describe Histogrammable, type: :model do
  describe ".histogram_bins" do
    let!(:pws_a) { create(:public_water_system) }
    let!(:pws_b) { create(:public_water_system) }
    let!(:pws_c) { create(:public_water_system) }

    before do
      create(:demographic, public_water_system: pws_a, pwsid: pws_a.pwsid, poverty_rate: 10)
      create(:demographic, public_water_system: pws_b, pwsid: pws_b.pwsid, poverty_rate: 20)
      create(:demographic, public_water_system: pws_c, pwsid: pws_c.pwsid, poverty_rate: nil)
    end

    it "returns bins, domain_min, and domain_max" do
      result = Demographic.histogram_bins(:poverty_rate)
      expect(result).to include(:bins, :domain_min, :domain_max)
      expect(result[:bins]).to be_an(Array)
    end

    it "excludes nil values" do
      result = Demographic.histogram_bins(:poverty_rate)
      expect(result[:domain_min]).to eq(10)
    end

    it "excludes rows at or below the default min_threshold (0)" do
      pws_d = create(:public_water_system)
      create(:demographic, public_water_system: pws_d, pwsid: pws_d.pwsid, poverty_rate: 0)

      result = Demographic.histogram_bins(:poverty_rate)
      expect(result[:domain_min]).to eq(10)
    end

    it "returns empty result when no rows match" do
      Demographic.delete_all
      result = Demographic.histogram_bins(:poverty_rate)
      expect(result).to eq({bins: [], domain_min: 0, domain_max: 0})
    end

    it "handles single-value data without error" do
      Demographic.delete_all
      pws_e = create(:public_water_system)
      create(:demographic, public_water_system: pws_e, pwsid: pws_e.pwsid, poverty_rate: 15)

      result = Demographic.histogram_bins(:poverty_rate)
      expect(result[:domain_min]).to eq(15)
      expect(result[:domain_max]).to eq(15)
      expect(result[:bins]).to be_an(Array)
    end

    it "includes negative values when min_threshold is nil" do
      pws_f = create(:public_water_system)
      create(:trend_datum, public_water_system: pws_f, pwsid: pws_f.pwsid, population_pct_change: -5)

      result = TrendDatum.histogram_bins(:population_pct_change, min_threshold: nil)
      expect(result[:domain_min]).to be <= -5
    end
  end
end
