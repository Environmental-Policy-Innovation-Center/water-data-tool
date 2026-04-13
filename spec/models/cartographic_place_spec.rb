require "rails_helper"

RSpec.describe CartographicPlace, type: :model do
  it "is valid with required fields" do
    place = build(:cartographic_place)
    expect(place).to be_valid
  end
end
