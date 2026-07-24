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
class BoilWaterSummary < ApplicationRecord
  include Histogrammable

  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :boil_water_summary

  validates :pwsid, presence: true
end
