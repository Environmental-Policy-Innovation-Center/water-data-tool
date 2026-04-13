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
class PublicWaterSystem < ApplicationRecord
  include Filterable

  self.primary_key = "pwsid"

  has_one :service_area_geometry, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :demographic, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :violations_summary, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :environmental_justice, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :funding_summary, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :watershed_hazard, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :boil_water_summary, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :trend_datum, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_many :place_system_crosswalks, foreign_key: "pwsid", dependent: :destroy
  has_many :cartographic_places, through: :place_system_crosswalks

  validates :pwsid, presence: true, format: {with: /\A[A-Z]{2}\d{7}\z/}
end
