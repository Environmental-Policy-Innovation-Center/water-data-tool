FactoryBot.define do
  factory :data_import do
    sequence(:file_url) { |n| "https://s3.example.com/data/file_#{n}.csv" }
    imported_at { Time.current }
  end
end
