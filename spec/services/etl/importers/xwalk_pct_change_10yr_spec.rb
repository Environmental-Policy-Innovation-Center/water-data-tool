require "rails_helper"

RSpec.describe Etl::Importers::XwalkPctChange10yr do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/xwalk_pct_change_10yr.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one row per CSV line" do
      expect(rows.length).to eq(2)
    end

    it "maps legacy column names to new schema names" do
      expect(rows.first).to have_key(:population_pct_change)
      expect(rows.first).to have_key(:mhi_pct_change)
      expect(rows.first).to have_key(:income_change_flag)
    end

    it "casts decimal columns" do
      expect(rows.first[:population_pct_change]).to eq(BigDecimal("5.2"))
    end

    it "preserves string flag columns" do
      expect(rows.first[:income_change_flag]).to eq("Increasing Income")
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
    end

    it "creates trend_data records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(TrendDatum, :count).by(2)
    end
  end
end
