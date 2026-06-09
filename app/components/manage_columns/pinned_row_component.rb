class ManageColumns::PinnedRowComponent < ViewComponent::Base
  def initialize(col:)
    @col = col
  end
end
