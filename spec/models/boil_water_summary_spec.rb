# == Schema Information
#
# Table name: boil_water_summaries
#
#  id                       :bigint           not null, primary key
#  date_range_display       :string
#  download_url             :string
#  first_advisory_date      :string
#  last_advisory_date       :string
#  pwsid                    :string           not null
#  state                    :string
#  state_reporting_year_max :string
#  state_reporting_year_min :string
#  tooltip_text             :text
#  total_notices            :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_boil_water_summaries_on_pwsid  (pwsid) UNIQUE
#
require "rails_helper"

RSpec.describe BoilWaterSummary, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:public_water_system).with_foreign_key("pwsid") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:pwsid) }
  end
end
