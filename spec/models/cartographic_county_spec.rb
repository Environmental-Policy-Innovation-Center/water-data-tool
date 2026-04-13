require "rails_helper"

RSpec.describe CartographicCounty, type: :model do
  it "is valid with required fields" do
    county = build(:cartographic_county)
    expect(county).to be_valid
  end
end
