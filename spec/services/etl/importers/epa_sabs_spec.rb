require "rails_helper"

RSpec.describe Etl::Importers::EpaSabs do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/epa_sabs.csv")) }

  describe "#parse" do
    subject(:rows) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago).parse(csv_content) }

    it "returns one row per CSV line" do
      expect(rows.length).to eq(3)
    end

    it "maps pwsid" do
      expect(rows.first[:pwsid]).to eq("VT0000001")
    end

    it "casts population_served_count as integer" do
      expect(rows.first[:population_served_count]).to eq(1500)
    end

    it "casts area_sq_miles as decimal" do
      expect(rows.first[:area_sq_miles]).to eq(BigDecimal("12.5"))
    end

    it "maps epic_area_mi2 to area_sq_miles" do
      expect(rows.first).to have_key(:area_sq_miles)
    end

    it "returns nil for NA area values" do
      expect(rows.second[:area_sq_miles]).to be_nil
    end

    it "derives stusps from the first two characters of pwsid" do
      expect(rows.first[:stusps]).to eq("VT")
    end

    it "includes timestamps" do
      expect(rows.first).to have_key(:created_at)
      expect(rows.first).to have_key(:updated_at)
    end

    context "with NA string values in the source CSV" do
      let(:na_row) { rows.last }

      it "converts NA pws_name to nil" do
        expect(na_row[:pws_name]).to be_nil
      end

      it "converts NA pop_cat_5 to nil" do
        expect(na_row[:pop_cat_5]).to be_nil
      end

      it "converts NA service_area_type to nil" do
        expect(na_row[:service_area_type]).to be_nil
      end

      it "converts NA detailed_facility_report to nil" do
        expect(na_row[:detailed_facility_report]).to be_nil
      end

      it "converts NA ewg_report_link to nil" do
        expect(na_row[:ewg_report_link]).to be_nil
      end

      it "preserves real string values on the same row" do
        expect(na_row[:primacy_agency]).to eq("Vermont DEC")
        expect(na_row[:symbology_field]).to eq("System Sourced")
      end
    end
  end

  describe "#import!" do
    let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

    it "upserts rows into public_water_systems" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(PublicWaterSystem, :count).by(3)
    end

    it "updates existing records on conflict" do
      create(:public_water_system, pwsid: "VT0000001", pws_name: "Old Name")
      rows = importer.parse(csv_content)
      importer.import!(rows)
      expect(PublicWaterSystem.find("VT0000001").pws_name).to eq("Green Mountain Water")
    end

    it "stores nil (not NA string) for NA string columns" do
      rows = importer.parse(csv_content)
      importer.import!(rows)
      pws = PublicWaterSystem.find("VT0000003")
      expect(pws.pws_name).to be_nil
      expect(pws.pop_cat_5).to be_nil
      expect(pws.service_area_type).to be_nil
    end

    it "returns changed pwsids for inserted rows" do
      rows = importer.parse(csv_content)

      result = importer.import!(rows)

      expect(result).to have_attributes(
        status: :imported,
        changed_pwsids: contain_exactly("VT0000001", "VT0000002", "VT0000003"),
        changed_layers: ["pws"]
      )
    end

    it "does not mark rows changed when map fields are unchanged" do
      rows = importer.parse(csv_content)
      importer.import!(rows)

      result = importer.import!(rows.map { |row| row.merge(primacy_agency: "Different agency") })

      expect(result.changed_pwsids).to be_empty
      expect(result.changed_layers).to be_empty
    end

    it "marks rows changed when map fields change" do
      rows = importer.parse(csv_content)
      importer.import!(rows)

      changed = rows.map { |row|
        (row[:pwsid] == "VT0000001") ? row.merge(pws_name: "Renamed System") : row
      }
      result = importer.import!(changed)

      expect(result.changed_pwsids).to eq(["VT0000001"])
      expect(result.changed_layers).to eq(["pws"])
    end
  end
end
