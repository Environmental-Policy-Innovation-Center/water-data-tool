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
FactoryBot.define do
  factory :certification_summary do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    rra_certification { ["Certified", "Uncertified"].sample }
  end
end
