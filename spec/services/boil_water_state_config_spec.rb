require "rails_helper"

RSpec.describe BoilWaterStateConfig do
  describe ".states" do
    it "returns an array of uppercase state abbreviations" do
      expect(described_class.states).to be_an(Array)
      expect(described_class.states).to all(match(/\A[A-Z]{2}\z/))
    end

    it "includes the 13 known BWN states" do
      expect(described_class.states).to include("AK", "AR", "LA", "MA", "ME", "MO", "NM", "OH", "OR", "RI", "TX", "WA", "WV")
    end

    it "does not include FL" do
      expect(described_class.states).not_to include("FL")
    end
  end

  describe ".bwn_state?" do
    it "returns true for a known BWN state" do
      expect(described_class.bwn_state?("TX")).to be true
    end

    it "is case-insensitive" do
      expect(described_class.bwn_state?("tx")).to be true
      expect(described_class.bwn_state?("Tx")).to be true
    end

    it "returns false for a non-BWN state" do
      expect(described_class.bwn_state?("CA")).to be false
    end

    it "returns false for nil" do
      expect(described_class.bwn_state?(nil)).to be false
    end

    it "returns false for blank string" do
      expect(described_class.bwn_state?("")).to be false
    end
  end

  describe ".states_json" do
    it "returns valid JSON encoding the states array" do
      parsed = JSON.parse(described_class.states_json)
      expect(parsed).to eq(described_class.states)
    end
  end
end
