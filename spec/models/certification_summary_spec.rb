# == Schema Information
#
# Table name: certification_summaries
#
#  id                :bigint           not null, primary key
#  pwsid             :string           not null
#  rra_certification :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_certification_summaries_on_pwsid  (pwsid) UNIQUE
#
require "rails_helper"

RSpec.describe CertificationSummary, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:public_water_system).with_foreign_key("pwsid") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:pwsid) }
  end
end
