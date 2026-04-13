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
require "rails_helper"

RSpec.describe DataImport, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:file_url) }
    it { is_expected.to validate_presence_of(:imported_at) }
  end
end
