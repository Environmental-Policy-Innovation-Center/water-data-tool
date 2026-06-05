require "rails_helper"

RSpec.describe Etl::Importers::SdwisViols do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/sdwis_viols.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one pws_row and one viol_row per CSV line" do
      expect(rows[:pws_rows].length).to eq(4)
      expect(rows[:viol_rows].length).to eq(4)
    end

    it "casts boolean indicators on pws_rows" do
      expect(rows[:pws_rows].first[:is_grant_eligible]).to be(true)
      expect(rows[:pws_rows].first[:is_wholesaler]).to be(false)
      expect(rows[:pws_rows].first[:open_health_viol]).to be(false)
    end

    it "casts source_water_protection_code Yes as true" do
      expect(rows[:pws_rows].first[:source_water_protection_code]).to be(true)
    end

    it "casts source_water_protection_code No as false" do
      expect(rows[:pws_rows][1][:source_water_protection_code]).to be(false)
    end

    it "casts source_water_protection_code No Information as nil" do
      expect(rows[:pws_rows][2][:source_water_protection_code]).to be_nil
    end

    it "casts violation counts as integers" do
      expect(rows[:viol_rows].first[:health_violations_5yr]).to eq(2)
      expect(rows[:viol_rows].first[:total_violations_10yr]).to eq(6)
    end

    it "maps legacy column names to new schema names" do
      viol = rows[:viol_rows].first
      expect(viol).to have_key(:groundwater_rule_5yr)
      expect(viol).to have_key(:surface_water_treatment_5yr)
      expect(viol).to have_key(:lead_and_copper_5yr)
    end

    context "with NA string values in the source CSV" do
      let(:na_row) { rows[:pws_rows].last }

      it "converts NA gw_sw_code to nil" do
        expect(na_row[:gw_sw_code]).to be_nil
      end

      it "converts NA primary_source_code to nil" do
        expect(na_row[:primary_source_code]).to be_nil
      end

      it "converts NA first_reported_date to nil" do
        expect(na_row[:first_reported_date]).to be_nil
      end

      it "converts NA owner_type to nil" do
        expect(na_row[:owner_type]).to be_nil
      end

      it "converts NA primacy_type to nil" do
        expect(na_row[:primacy_type]).to be_nil
      end

      it "converts NA source_water_protection_code to nil" do
        expect(na_row[:source_water_protection_code]).to be_nil
      end

      it "converts NA phone_number to nil" do
        expect(na_row[:phone_number]).to be_nil
      end

      it "converts NA open_health_viol to nil" do
        expect(na_row[:open_health_viol]).to be_nil
      end
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
      create(:public_water_system, pwsid: "VT0000003")
      create(:public_water_system, pwsid: "VT0000004")
    end

    it "upserts pws attribute columns and creates violations_summaries" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(ViolationsSummary, :count).by(4)
    end

    it "sets boolean fields on PublicWaterSystem" do
      rows = importer.parse(csv_content)
      importer.import!(rows)
      pws = PublicWaterSystem.find("VT0000001")
      expect(pws.is_grant_eligible).to be(true)
      expect(pws.is_wholesaler).to be(false)
      expect(pws.source_water_protection_code).to be(true)
    end

    it "stores nil for No Information source_water_protection_code" do
      rows = importer.parse(csv_content)
      importer.import!(rows)
      pws = PublicWaterSystem.find("VT0000003")
      expect(pws.source_water_protection_code).to be_nil
    end

    it "stores nil (not NA string) for NA string columns" do
      rows = importer.parse(csv_content)
      importer.import!(rows)
      pws = PublicWaterSystem.find("VT0000004")
      expect(pws.gw_sw_code).to be_nil
      expect(pws.owner_type).to be_nil
      expect(pws.primacy_type).to be_nil
      expect(pws.open_health_viol).to be_nil
    end
  end
end
