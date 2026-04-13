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
FactoryBot.define do
  factory :funding_summary do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    times_funded { 2 }
    total_srf_assistance { 850_000.00 }
    median_srf_assistance { 425_000.00 }
    total_principal_forgiveness { 200_000.00 }
  end
end
