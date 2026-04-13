require "rails_helper"

RSpec.describe CartographicState, type: :model do
  it "is valid with required fields" do
    state = build(:cartographic_state)
    expect(state).to be_valid
  end
end
