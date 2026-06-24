require "rails_helper"

RSpec.describe Etl::Importers::NationalBwnHighlevelSummary do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/national_bwn_highlevel_summary.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one row per CSV line" do
      expect(rows.length).to eq(3)
    end

    it "maps date_of_first_advisory to first_advisory_date" do
      expect(rows.first[:first_advisory_date]).to eq("2015-03-12")
    end

    it "casts total_bwn as integer" do
      expect(rows.first[:total_notices]).to eq(3)
    end

    context "with NA advisory date values" do
      let(:na_row) { rows.last }

      it "converts NA first_advisory_date to nil" do
        expect(na_row[:first_advisory_date]).to be_nil
      end

      it "converts NA last_advisory_date to nil" do
        expect(na_row[:last_advisory_date]).to be_nil
      end

      it "converts blank date_range_display to nil" do
        expect(na_row[:date_range_display]).to be_nil
      end
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
      create(:public_water_system, pwsid: "VT0000003")
    end

    it "creates boil_water_summary records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(BoilWaterSummary, :count).by(3)
    end

    it "stores nil (not NA string) for NA date columns" do
      rows = importer.parse(csv_content)
      importer.import!(rows)
      bws = BoilWaterSummary.find_by(pwsid: "VT0000003")
      expect(bws.first_advisory_date).to be_nil
      expect(bws.last_advisory_date).to be_nil
    end

    it "returns an import result without tile refresh layers" do
      rows = importer.parse(csv_content)
      result = importer.import!(rows)

      expect(result).to eq(
        Etl::ImportResult.imported(file_key: "f", changed_layers: [])
      )
    end
  end
end
