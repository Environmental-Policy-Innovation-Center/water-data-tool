class DataImport < ApplicationRecord
  validates :file_url, presence: true
  validates :imported_at, presence: true
end
