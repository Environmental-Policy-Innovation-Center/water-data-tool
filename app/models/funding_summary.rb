class FundingSummary < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :funding_summary

  validates :pwsid, presence: true
end
