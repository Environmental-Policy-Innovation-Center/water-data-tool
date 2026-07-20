require "rails_helper"
require Rails.root.join("db/migrate/20260714000001_trim_boil_water_summary_pwsid")

RSpec.describe TrimBoilWaterSummaryPwsid do
  describe "#up" do
    it "trims a whitespace-padded pwsid" do
      padded = create(:boil_water_summary)
      clean_pwsid = padded.pwsid
      padded.update_column(:pwsid, "#{clean_pwsid}   ")

      described_class.new.up

      expect(padded.reload.pwsid).to eq(clean_pwsid)
    end

    it "leaves an already-clean pwsid unchanged" do
      clean = create(:boil_water_summary)

      expect { described_class.new.up }.not_to change { clean.reload.pwsid }
    end

    it "is a safe no-op when the table is empty" do
      expect(BoilWaterSummary.count).to eq(0)

      expect { described_class.new.up }.not_to raise_error
    end
  end

  describe "#down" do
    it "is irreversible" do
      expect { described_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
    end
  end
end
