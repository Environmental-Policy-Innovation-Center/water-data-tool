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
end
