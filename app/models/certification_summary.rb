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
class CertificationSummary < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :certification_summary

  validates :pwsid, presence: true
end
