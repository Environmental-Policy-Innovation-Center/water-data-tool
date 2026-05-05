require "rails_helper"

RSpec.describe Etl::Importers::XwalkPctChange10yr do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/xwalk_pct_change_10yr.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one row per CSV line" do
      expect(rows.length).to eq(3)
    end

    it "maps legacy column names to new schema names" do
      expect(rows.first).to have_key(:population_pct_change)
      expect(rows.first).to have_key(:mhi_pct_change)
      expect(rows.first).to have_key(:income_change_flag)
    end

    it "casts decimal columns" do
      expect(rows.first[:population_pct_change]).to eq(BigDecimal("5.2"))
    end

    it "preserves real string flag values" do
      expect(rows.first[:income_change_flag]).to eq("Increasing Income")
      expect(rows.first[:population_change_flag]).to eq("Stable")
    end

    context "with NA flag values" do
      let(:na_row) { rows.last }

      it "converts NA income_change_flag to nil" do
        expect(na_row[:income_change_flag]).to be_nil
      end

      it "converts NA population_change_flag to nil" do
        expect(na_row[:population_change_flag]).to be_nil
      end
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
      create(:public_water_system, pwsid: "VT0000003")
    end

    it "creates trend_data records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(TrendDatum, :count).by(3)
    end

    it "stores nil (not NA string) for NA flag columns" do
      rows = importer.parse(csv_content)
      importer.import!(rows)
      td = TrendDatum.find_by(pwsid: "VT0000003")
      expect(td.income_change_flag).to be_nil
      expect(td.population_change_flag).to be_nil
    end
  end
end
