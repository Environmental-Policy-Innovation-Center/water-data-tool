class CartographicPlace < ApplicationRecord
  self.primary_key = "gid"

  has_many :place_system_crosswalks, foreign_key: "geoid", primary_key: "geoid"
  has_many :public_water_systems, through: :place_system_crosswalks
end
