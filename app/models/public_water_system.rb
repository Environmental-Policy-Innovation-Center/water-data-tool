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
#  source_water_protection_code :boolean
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

  PWSID_FORMAT = /\A[A-Z0-9]{9}\z/

  self.primary_key = "pwsid"

  has_one :service_area_geometry, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :demographic, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :violations_summary, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :environmental_justice, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :funding_summary, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :watershed_hazard, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :boil_water_summary, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :trend_datum, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_one :certification_summary, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
  has_many :place_system_crosswalks, foreign_key: "pwsid", dependent: :destroy
  has_many :cartographic_places, through: :place_system_crosswalks

  scope :with_details, -> {
    includes(:demographic, :violations_summary, :environmental_justice,
      :funding_summary, :watershed_hazard, :boil_water_summary,
      :trend_datum, :service_area_geometry)
  }

  validates :pwsid, presence: true, format: {with: PWSID_FORMAT}

  alias_attribute :area, :area_sq_miles
  alias_attribute :counties_served, :counties
  alias_attribute :name, :pws_name
  alias_attribute :population_served, :population_served_count
  alias_attribute :report_link, :detailed_facility_report
  alias_attribute :source_protection, :source_water_protection_code

  # unscope(:order) required — ORDER BY is invalid on aggregates.
  # left_joins(:demographic) may duplicate a join from apply_filters, but PostgreSQL
  # handles duplicate LEFT JOINs on a non-nullable PK cleanly.
  def self.build_summary(scope)
    total_pop, open_viol_count, avg_mhi, systems_count = scope.unscope(:order)
      .left_joins(:demographic)
      .pick(
        Arel.sql("SUM(population_served_count)"),
        Arel.sql("COUNT(*) FILTER (WHERE open_health_viol)"),
        Arel.sql("ROUND(AVG(demographics.median_household_income))"),
        Arel.sql("COUNT(DISTINCT public_water_systems.pwsid)")
      )
    {
      systems_count: systems_count,
      total_population_served: total_pop,
      systems_with_open_violations: open_viol_count,
      avg_median_household_income: avg_mhi
    }
  end
end
