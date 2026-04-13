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
class FundingSummary < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :funding_summary

  validates :pwsid, presence: true
end
