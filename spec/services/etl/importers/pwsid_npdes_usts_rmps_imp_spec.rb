require "rails_helper"

RSpec.describe Etl::Importers::PwsidNpdesUstsRmpsImp do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/pwsid_npdes_usts_rmps_imp.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "pre-aggregates multiple HUC12 rows into one row per pwsid" do
      expect(rows.length).to eq(2)
    end

    it "sums numeric columns across HUC12 rows for the same pwsid" do
      vt1 = rows.find { |r| r[:pwsid] == "VT0000001" }
      expect(vt1[:num_facilities]).to eq(8)         # 5 + 3
      expect(vt1[:npdes_permits]).to eq(5)           # 3 + 2
      expect(vt1[:impaired_streams_303d]).to eq(6)   # 4 + 2
    end

    it "drops the huc12 column" do
      expect(rows.first).not_to have_key(:huc12)
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
    end

    it "creates watershed_hazard records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(WatershedHazard, :count).by(2)
    end
  end
end
