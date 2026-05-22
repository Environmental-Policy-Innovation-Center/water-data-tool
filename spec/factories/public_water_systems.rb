# == Schema Information
#
# Table name: public_water_systems
#
#  area_sq_miles                :decimal(, )
#  counties                     :text
#  detailed_facility_report     :string
#  ewg_report_link              :string
#  first_reported_date          :string
#  gw_sw_code                   :string
#  is_grant_eligible            :boolean
#  is_school_or_daycare         :boolean
#  is_wholesaler                :boolean
#  open_health_viol             :boolean
#  owner_type                   :string
#  phone_number                 :string
#  pop_cat_5                    :string
#  population_served_count      :integer
#  primacy_agency               :string
#  primacy_type                 :string
#  primary_source_code          :string
#  pws_name                     :string
#  pwsid                        :string           not null, primary key
#  service_area_type            :string
#  service_connections_count    :integer
#  source_water_protection_code :string
#  stusps                       :string(2)
#  symbology_field              :string
#  years_operating              :integer
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
# Indexes
#
#  index_public_water_systems_on_gw_sw_code    (gw_sw_code)
#  index_public_water_systems_on_owner_type    (owner_type)
#  index_public_water_systems_on_pop_cat_5     (pop_cat_5)
#  index_public_water_systems_on_primacy_type  (primacy_type)
#  index_public_water_systems_on_stusps        (stusps)
#
FactoryBot.define do
  factory :public_water_system do
    sequence(:pwsid) { |n| "VT#{format("%07d", n)}" }
    pws_name { "Green Mountain Water District" }
    stusps { "VT" }
    primacy_agency { "Vermont DEC" }
    pop_cat_5 { "<=500" }
    population_served_count { 1500 }
    service_connections_count { 600 }
    service_area_type { "Residential Area" }
    symbology_field { "System Sourced" }
    gw_sw_code { "Groundwater" }
    primary_source_code { "GW" }
    owner_type { "Local" }
    primacy_type { "State" }
    years_operating { 45 }
    first_reported_date { "1980-01-01" }
    is_wholesaler { false }
    is_school_or_daycare { false }
    is_grant_eligible { true }
    source_water_protection_code { "Yes" }
    open_health_viol { false }
    phone_number { "802-555-0100" }
    area_sq_miles { 12.5 }
    counties { "Washington" }
  end
end
