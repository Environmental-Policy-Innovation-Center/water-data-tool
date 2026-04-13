FactoryBot.define do
  factory :public_water_system do
    sequence(:pwsid) { |n| "VT#{format('%07d', n)}" }
    pws_name { "Green Mountain Water District" }
    stusps { "VT" }
    primacy_agency { "Vermont DEC" }
    pop_cat_5 { "Small" }
    population_served_count { 1500 }
    service_connections_count { 600 }
    service_area_type { "System Sourced" }
    symbology_field { "Community Water System" }
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
    open_health_viol { "No" }
    phone_number { "802-555-0100" }
    area_sq_miles { 12.5 }
    counties { "Washington" }
  end
end
