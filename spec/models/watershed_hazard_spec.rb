# == Schema Information
#
# Table name: watershed_hazards
#
#  id                              :bigint           not null, primary key
#  impaired_streams_303d           :integer
#  npdes_permits                   :integer
#  num_facilities                  :integer
#  open_underground_storage_tanks  :integer
#  permit_effluent_violations      :integer
#  pwsid                           :string           not null
#  risk_management_plan_facilities :integer
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#
# Indexes
#
#  index_watershed_hazards_on_pwsid  (pwsid) UNIQUE
#
require "rails_helper"

RSpec.describe WatershedHazard, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:public_water_system).with_foreign_key("pwsid") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:pwsid) }
  end
end
