require "rails_helper"

RSpec.describe TileCache, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:layer) }
    it { is_expected.to validate_presence_of(:z) }
    it { is_expected.to validate_presence_of(:x) }
    it { is_expected.to validate_presence_of(:y) }
  end

  it "is valid with required fields" do
    tile = build(:tile_cache, layer: "pws", z: 5, x: 10, y: 12)
    expect(tile).to be_valid
  end

  describe "composite primary key uniqueness" do
    it "raises on duplicate (layer, z, x, y)" do
      create(:tile_cache, layer: "pws", z: 5, x: 10, y: 12)
      duplicate = build(:tile_cache, layer: "pws", z: 5, x: 10, y: 12)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows same coordinates on a different layer" do
      create(:tile_cache, layer: "pws", z: 5, x: 10, y: 12)
      other = build(:tile_cache, layer: "states", z: 5, x: 10, y: 12)
      expect { other.save!(validate: false) }.not_to raise_error
    end
  end
end
