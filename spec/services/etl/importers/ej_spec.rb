require "rails_helper"

# The four EJ importers (CEJST, EJScreen, SVI, CVI) each write to the
# environmental_justices table, merging columns from separate source files.
# Tests cover parse and import! for each.

RSpec.describe Etl::Importers::Cejst do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/cejst.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one row per CSV line" do
      expect(rows.length).to eq(2)
    end

    it "applies cast_score to identified_as_disadvantaged (0-to-1 → ×100)" do
      expect(rows.first[:cejst_disadvantaged_pct]).to eq(65.0)
    end

    it "returns nil for NA scores" do
      expect(rows.last[:cejst_disadvantaged_pct]).to be_nil
    end

    it "casts lead_paint_indicator as integer" do
      expect(rows.first[:cejst_lead_paint_indicator]).to eq(1)
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
    end

    it "upserts environmental_justice records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(EnvironmentalJustice, :count).by(2)
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

RSpec.describe Etl::Importers::Ejscreen do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/ejscreen.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "returns one row per CSV line" do
      expect(rows.length).to eq(2)
    end

    it "maps a_int.dwater to ejscreen_drinking_water" do
      expect(rows.first[:ejscreen_drinking_water]).to eq(BigDecimal("45.2"))
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
    end

    it "upserts environmental_justice records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(EnvironmentalJustice, :count).by(2)
    end

    it "updates existing EJ record rather than inserting a duplicate" do
      rows = importer.parse(csv_content)
      importer.import!(rows)
      expect { importer.import!(rows) }.not_to change(EnvironmentalJustice, :count)
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

RSpec.describe Etl::Importers::Svi do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/svi.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "applies cast_score to rpl_themes" do
      expect(rows.first[:svi_overall_pctl]).to eq(42.0)
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
    end

    it "upserts environmental_justice records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(EnvironmentalJustice, :count).by(2)
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

RSpec.describe Etl::Importers::Cvi do
  let(:csv_content) { File.read(Rails.root.join("spec/fixtures/etl/cvi.csv")) }
  let(:importer) { described_class.new(file_url: "http://x.com/f.csv", last_updated: 1.day.ago) }

  describe "#parse" do
    subject(:rows) { importer.parse(csv_content) }

    it "applies cast_score to overall_cvi_score" do
      expect(rows.first[:cvi_overall_score]).to eq(58.0)
    end

    it "casts cvi_redlining as decimal" do
      expect(rows.first[:cvi_redlining]).to eq(BigDecimal("0.35"))
    end
  end

  describe "#import!" do
    before do
      create(:public_water_system, pwsid: "VT0000001")
      create(:public_water_system, pwsid: "VT0000002")
    end

    it "upserts environmental_justice records" do
      rows = importer.parse(csv_content)
      expect { importer.import!(rows) }.to change(EnvironmentalJustice, :count).by(2)
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
