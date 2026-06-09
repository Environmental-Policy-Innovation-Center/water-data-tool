class ManageColumns::CategoryHeaderRowComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(cat:)
    @cat = cat
  end
end
