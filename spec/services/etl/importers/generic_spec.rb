require "rails_helper"

# Etl::Importers::Generic is the sole flat-map importer (Phase 4 of docs/CONFIG_AUDIT.md):
# it parses each source file into {db_column => cast(row[header])} rows from
# FieldRegistry.etl_mapping and upserts them into the manifest-resolved model.
#
# These value assertions guard the manifest's source: wiring per file — header → column →
# cast, including raw passthrough and NA → nil. (The cast functions themselves are covered
# by type_caster_spec.) This replaced the cutover-time characterization spec that compared
# Generic against the now-deleted per-file importers.
RSpec.describe Etl::Importers::Generic do
  def parse_fixture(file_key)
    described_class.new(file_url: "https://example.test/#{file_key}.csv", last_updated: 1.day.ago)
      .parse(File.read(Rails.root.join("spec/fixtures/etl/#{file_key}.csv")))
  end

  describe "#parse maps headers to columns with the manifest's casts" do
    it "cejst: score (×100) and integer" do
      expect(parse_fixture("cejst").first).to include(cejst_disadvantaged_pct: 65.0, cejst_lead_paint_indicator: 1)
    end

    it "ejscreen: decimal" do
      expect(parse_fixture("ejscreen").first[:ejscreen_drinking_water]).to eq(BigDecimal("45.2"))
    end

    it "svi: score" do
      expect(parse_fixture("svi").first[:svi_overall_pctl]).to eq(42.0)
    end

    it "cvi: score and decimal" do
      expect(parse_fixture("cvi").first).to include(cvi_overall_score: 58.0, cvi_redlining: BigDecimal("0.35"))
    end

    it "epa_sabs_xwalk: integer, decimal, and raw passthrough for most_common_rate_tier" do
      row = parse_fixture("epa_sabs_xwalk").first
      expect(row).to include(total_population: 3200, median_household_income: 62000, poverty_rate: BigDecimal("10.5"))
      expect(row[:most_common_rate_tier]).to eq("$250-499")
    end

    it "xwalk_pct_change_10yr: decimal and string flags, NA → nil" do
      rows = parse_fixture("xwalk_pct_change_10yr")
      expect(rows.first).to include(population_pct_change: BigDecimal("5.2"), income_change_flag: "Increasing Income")
      expect(rows.last[:income_change_flag]).to be_nil
    end

    it "national_bwn_highlevel_summary: integer and string, NA → nil" do
      rows = parse_fixture("national_bwn_highlevel_summary")
      expect(rows.first).to include(total_notices: 3, first_advisory_date: "2015-03-12")
      expect(rows.last[:first_advisory_date]).to be_nil
    end

    it "pwsid_funded_highlevel_summary: integer and decimal" do
      expect(parse_fixture("pwsid_funded_highlevel_summary").first)
        .to include(times_funded: 2, total_srf_assistance: BigDecimal("850000.00"))
    end

    it "trims whitespace-padded pwsid values (some source files pad fixed-width fields)" do
      content = File.read(Rails.root.join("spec/fixtures/etl/national_bwn_highlevel_summary.csv"))
        .sub("VT0000001", "VT0000001   ")
      rows = described_class.new(file_url: "https://example.test/national_bwn_highlevel_summary.csv", last_updated: 1.day.ago)
        .parse(content)
      expect(rows.first[:pwsid]).to eq("VT0000001")
    end
  end

  describe "#import! upserts into the manifest-resolved model" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
      create(:public_water_system, pwsid: "VT0000003")
    end

    def import(file_key)
      importer = described_class.new(file_url: "https://example.test/#{file_key}.csv", last_updated: 1.day.ago)
      importer.import!(importer.parse(File.read(Rails.root.join("spec/fixtures/etl/#{file_key}.csv"))))
    end

    it "routes each file to the model its manifest fields declare" do
      expect { import("cvi") }.to change(EnvironmentalJustice, :count).by(2)
      expect { import("epa_sabs_xwalk") }.to change(Demographic, :count).by(2)
      expect { import("xwalk_pct_change_10yr") }.to change(TrendDatum, :count).by(3)
      expect { import("national_bwn_highlevel_summary") }.to change(BoilWaterSummary, :count).by(3)
      expect { import("pwsid_funded_highlevel_summary") }.to change(FundingSummary, :count).by(2)
    end

    it "stores nil (not the 'NA' string) for NA values" do
      import("xwalk_pct_change_10yr")
      expect(TrendDatum.find_by(pwsid: "VT0000003").income_change_flag).to be_nil
    end
  end
end
