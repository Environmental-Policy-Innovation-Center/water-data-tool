# == Schema Information
#
# Table name: cartographic_states
#
#  geoid   :string(2)
#  geom    :geometry         multipolygon, 4326
#  gid     :integer          not null, primary key
#  name    :string
#  statefp :string(2)
#  stusps  :string(2)
#
# Indexes
#
#  index_cartographic_states_on_geom  (geom) USING gist
#
require "rails_helper"

RSpec.describe CartographicState, type: :model do
  it "is valid with required fields" do
    state = build(:cartographic_state)
    expect(state).to be_valid
  end
end
