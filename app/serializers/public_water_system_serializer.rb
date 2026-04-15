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
#  open_health_viol             :string
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
class PublicWaterSystemSerializer
  def initialize(pws)
    @pws = pws
  end

  def serialize
    {
      pwsid: @pws.pwsid,
      pws_name: @pws.pws_name,
      stusps: @pws.stusps,
      primacy_agency: @pws.primacy_agency,
      pop_cat_5: @pws.pop_cat_5,
      population_served_count: @pws.population_served_count,
      service_connections_count: @pws.service_connections_count,
      gw_sw_code: @pws.gw_sw_code,
      owner_type: @pws.owner_type,
      primacy_type: @pws.primacy_type,
      service_area_type: @pws.service_area_type,
      area_sq_miles: @pws.area_sq_miles,
      open_health_viol: @pws.open_health_viol,
      is_wholesaler: @pws.is_wholesaler,
      is_school_or_daycare: @pws.is_school_or_daycare,
      counties: @pws.counties
    }
  end
end
