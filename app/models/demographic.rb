class Demographic < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :demographic

  validates :pwsid, presence: true
end
