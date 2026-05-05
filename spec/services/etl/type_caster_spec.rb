require "rails_helper"

RSpec.describe Etl::TypeCaster do
  # Test via a plain object that includes the module, since TypeCaster
  # defines instance methods (not module-level functions).
  let(:caster) { Object.new.tap { |o| o.extend(described_class) } }

  describe "#cast_int" do
    it "converts a numeric string to integer" do
      expect(caster.cast_int("42")).to eq(42)
    end

    it "strips whitespace before casting" do
      expect(caster.cast_int("  100  ")).to eq(100)
    end

    it "returns nil for blank string" do
      expect(caster.cast_int("")).to be_nil
    end

    it "returns nil for whitespace-only string" do
      expect(caster.cast_int("   ")).to be_nil
    end

    it "returns nil for NA" do
      expect(caster.cast_int("NA")).to be_nil
    end

    it "returns nil for case-variant NA" do
      expect(caster.cast_int("na")).to be_nil
    end

    it "returns nil for nil" do
      expect(caster.cast_int(nil)).to be_nil
    end
  end

  describe "#cast_dec" do
    it "converts a decimal string to BigDecimal" do
      expect(caster.cast_dec("12.5")).to eq(BigDecimal("12.5"))
    end

    it "strips whitespace before casting" do
      expect(caster.cast_dec("  0.85  ")).to eq(BigDecimal("0.85"))
    end

    it "returns nil for blank string" do
      expect(caster.cast_dec("")).to be_nil
    end

    it "returns nil for NA" do
      expect(caster.cast_dec("NA")).to be_nil
    end

    it "returns nil for nil" do
      expect(caster.cast_dec(nil)).to be_nil
    end
  end

  describe "#cast_bool" do
    it "returns true for Y" do
      expect(caster.cast_bool("Y")).to be(true)
    end

    it "returns true for Yes (current source format)" do
      expect(caster.cast_bool("Yes")).to be(true)
    end

    it "returns false for N" do
      expect(caster.cast_bool("N")).to be(false)
    end

    it "returns false for No (current source format)" do
      expect(caster.cast_bool("No")).to be(false)
    end

    it "is case-insensitive" do
      expect(caster.cast_bool("y")).to be(true)
      expect(caster.cast_bool("yes")).to be(true)
      expect(caster.cast_bool("n")).to be(false)
      expect(caster.cast_bool("no")).to be(false)
    end

    it "strips whitespace" do
      expect(caster.cast_bool("  Y  ")).to be(true)
      expect(caster.cast_bool("  Yes  ")).to be(true)
    end

    it "returns nil for blank string" do
      expect(caster.cast_bool("")).to be_nil
    end

    it "returns nil for nil" do
      expect(caster.cast_bool(nil)).to be_nil
    end
  end

  describe "#cast_string" do
    it "returns the value stripped" do
      expect(caster.cast_string("  Territory  ")).to eq("Territory")
    end

    it "passes through real categorical values unchanged" do
      expect(caster.cast_string("State")).to eq("State")
      expect(caster.cast_string("Territory")).to eq("Territory")
      expect(caster.cast_string("No")).to eq("No")
      expect(caster.cast_string("Yes")).to eq("Yes")
      expect(caster.cast_string("No Information")).to eq("No Information")
      expect(caster.cast_string("Not Enough Data - Operating < 10 years")).to eq("Not Enough Data - Operating < 10 years")
    end

    it "returns nil for NA" do
      expect(caster.cast_string("NA")).to be_nil
    end

    it "returns nil for case-variant NA" do
      expect(caster.cast_string("na")).to be_nil
      expect(caster.cast_string("Na")).to be_nil
    end

    it "returns nil for blank string" do
      expect(caster.cast_string("")).to be_nil
    end

    it "returns nil for whitespace-only string" do
      expect(caster.cast_string("   ")).to be_nil
    end

    it "returns nil for nil" do
      expect(caster.cast_string(nil)).to be_nil
    end
  end

  describe "#cast_score" do
    it "converts a 0-to-1 float string to a percentage rounded to 2 decimal places" do
      expect(caster.cast_score("0.65")).to eq(65.0)
    end

    it "rounds to 2 decimal places" do
      expect(caster.cast_score("0.1234")).to eq(12.34)
    end

    it "handles 0" do
      expect(caster.cast_score("0")).to eq(0.0)
    end

    it "handles 1.0 (maximum score)" do
      expect(caster.cast_score("1.0")).to eq(100.0)
    end

    it "returns nil for blank string" do
      expect(caster.cast_score("")).to be_nil
    end

    it "returns nil for NA" do
      expect(caster.cast_score("NA")).to be_nil
    end

    it "returns nil for nil" do
      expect(caster.cast_score(nil)).to be_nil
    end
  end
end
