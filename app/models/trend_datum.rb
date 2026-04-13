class TrendDatum < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :trend_datum

  validates :pwsid, presence: true
end
