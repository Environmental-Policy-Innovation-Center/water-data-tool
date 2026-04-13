require "rails_helper"

RSpec.describe DataImport, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:file_url) }
    it { is_expected.to validate_presence_of(:imported_at) }
  end
end
