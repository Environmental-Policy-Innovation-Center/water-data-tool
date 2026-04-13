# == Schema Information
#
# Table name: data_imports
#
#  id          :bigint           not null, primary key
#  file_url    :string           not null
#  imported_at :datetime         not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_data_imports_on_file_url  (file_url)
#
class DataImport < ApplicationRecord
  validates :file_url, presence: true
  validates :imported_at, presence: true
end
