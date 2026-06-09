class ManageColumns::ColumnRowComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(col:, checked:, indented: false)
    @col = col
    @checked = checked
    @indented = indented
  end
end
