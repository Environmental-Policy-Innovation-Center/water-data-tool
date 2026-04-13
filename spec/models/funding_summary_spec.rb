# == Schema Information
#
# Table name: funding_summaries
#
#  id                          :bigint           not null, primary key
#  median_srf_assistance       :decimal(, )
#  pwsid                       :string           not null
#  times_funded                :integer
#  total_principal_forgiveness :decimal(, )
#  total_srf_assistance        :decimal(, )
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
# Indexes
#
#  index_funding_summaries_on_pwsid  (pwsid) UNIQUE
#
require "rails_helper"

RSpec.describe FundingSummary, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:public_water_system).with_foreign_key("pwsid") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:pwsid) }
  end
end
