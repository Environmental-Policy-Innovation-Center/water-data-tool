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
FactoryBot.define do
  factory :data_import do
    sequence(:file_url) { |n| "https://s3.example.com/data/file_#{n}.csv" }
    imported_at { Time.current }
  end
end
