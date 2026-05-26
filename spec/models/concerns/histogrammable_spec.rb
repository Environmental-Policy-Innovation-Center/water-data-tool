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

    it "always returns exactly num_bins entries" do
      result = Demographic.histogram_bins(:poverty_rate, num_bins: 10)
      expect(result[:bins].length).to eq(10)
    end

    it "fills empty buckets with count: 0 rather than omitting them" do
      result = Demographic.histogram_bins(:poverty_rate, num_bins: 10)
      counts = result[:bins].map { |b| b[:count] }
      expect(counts).to include(0)
      expect(counts.sum).to eq(2)
    end

    it "uses theoretical bin boundaries, not actual data min/max per bucket" do
      result = Demographic.histogram_bins(:poverty_rate, num_bins: 10)
      bins = result[:bins]
      bin_width = bins[0][:max] - bins[0][:min]
      bins.each_cons(2) do |a, b|
        expect(b[:min]).to be_within(0.0001).of(a[:max])
      end
      bins.each do |b|
        expect(b[:max] - b[:min]).to be_within(0.0001).of(bin_width)
      end
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
      create(:trend_datum, public_water_system: pws_f, pwsid: pws_f.pwsid, population_pct_change_capped: -5)

      result = TrendDatum.histogram_bins(:population_pct_change_capped, min_threshold: nil)
      expect(result[:bins].find { |b| b[:min] <= -5 && b[:max] > -5 }[:count]).to eq(1)
    end

    describe "format: percent" do
      it "uses fixed domain 0–100 regardless of actual data range" do
        result = Demographic.histogram_bins(:poverty_rate, format: "percent")
        expect(result[:domain_min]).to eq(0)
        expect(result[:domain_max]).to eq(100)
      end

      it "returns exactly 20 bins" do
        result = Demographic.histogram_bins(:poverty_rate, format: "percent")
        expect(result[:bins].length).to eq(20)
      end

      it "produces bins of exactly 5 percentage points each" do
        result = Demographic.histogram_bins(:poverty_rate, format: "percent")
        result[:bins].each do |bin|
          expect(bin[:max] - bin[:min]).to be_within(0.0001).of(5.0)
        end
      end

      it "covers the full 0–100 range" do
        result = Demographic.histogram_bins(:poverty_rate, format: "percent")
        expect(result[:bins].first[:min]).to be_within(0.0001).of(0)
        expect(result[:bins].last[:max]).to be_within(0.0001).of(100)
      end
    end

    describe "format: percent_change" do
      before do
        pws_g = create(:public_water_system)
        create(:trend_datum, public_water_system: pws_g, pwsid: pws_g.pwsid,
          population_pct_change_capped: 150)
      end

      it "uses fixed domain −200 to +200 to match the ETL cap" do
        result = TrendDatum.histogram_bins(:population_pct_change_capped, format: "percent_change")
        expect(result[:domain_min]).to eq(-200)
        expect(result[:domain_max]).to eq(200)
      end

      it "returns exactly 40 bins" do
        result = TrendDatum.histogram_bins(:population_pct_change_capped, format: "percent_change")
        expect(result[:bins].length).to eq(40)
      end

      it "produces bins of exactly 10 percentage points each" do
        result = TrendDatum.histogram_bins(:population_pct_change_capped, format: "percent_change")
        result[:bins].each do |bin|
          expect(bin[:max] - bin[:min]).to be_within(0.0001).of(10.0)
        end
      end

      it "includes values in the 100–200% range without clamping to an edge bin" do
        result = TrendDatum.histogram_bins(:population_pct_change_capped, format: "percent_change")
        bin_containing_150 = result[:bins].find { |b| b[:min] <= 150 && b[:max] > 150 }
        expect(bin_containing_150).not_to be_nil
        expect(bin_containing_150[:count]).to eq(1)
      end

      it "counts negative values without a min_threshold filter" do
        pws_h = create(:public_water_system)
        create(:trend_datum, public_water_system: pws_h, pwsid: pws_h.pwsid,
          population_pct_change_capped: -75)
        result = TrendDatum.histogram_bins(:population_pct_change_capped, format: "percent_change")
        bin = result[:bins].find { |b| b[:min] <= -75 && b[:max] > -75 }
        expect(bin[:count]).to be >= 1
      end
    end

    describe "format: count" do
      it "uses 1 bin per integer when domain_max <= 30" do
        pws_h = create(:public_water_system)
        create(:violations_summary, public_water_system: pws_h, pwsid: pws_h.pwsid,
          paperwork_violations_5yr: 5)

        result = ViolationsSummary.histogram_bins(:paperwork_violations_5yr, format: "count")
        expect(result[:bins].length).to eq(5)
      end

      it "caps at 30 bins when domain_max exceeds 30" do
        pws_i = create(:public_water_system)
        create(:violations_summary, public_water_system: pws_i, pwsid: pws_i.pwsid,
          paperwork_violations_5yr: 50)

        result = ViolationsSummary.histogram_bins(:paperwork_violations_5yr, format: "count")
        expect(result[:bins].length).to eq(30)
      end
    end
  end
end
