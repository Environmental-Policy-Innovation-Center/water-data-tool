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

  validates :pwsid, presence: true, format: { with: /\A[A-Z]{2}\d{7}\z/ }
end
