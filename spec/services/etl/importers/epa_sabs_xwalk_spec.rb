require "rails_helper"

RSpec.describe Etl::Importers::EpaSabsXwalk do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/epa_sabs_xwalk.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one row per CSV line" do
      expect(rows.length).to eq(2)
    end

    it "maps legacy column names to new schema names" do
      expect(rows.first).to have_key(:total_population)
      expect(rows.first).to have_key(:median_household_income)
      expect(rows.first).to have_key(:poverty_rate)
    end

    it "casts integer columns" do
      expect(rows.first[:total_population]).to eq(3200)
      expect(rows.first[:median_household_income]).to eq(62000)
    end

    it "casts decimal columns" do
      expect(rows.first[:poverty_rate]).to eq(BigDecimal("10.5"))
    end

    it "preserves most_common_rate_tidy as most_common_rate_tier string" do
      expect(rows.first[:most_common_rate_tier]).to eq("$250-499")
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
    end

    it "creates demographic records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(Demographic, :count).by(2)
    end
  end
end
