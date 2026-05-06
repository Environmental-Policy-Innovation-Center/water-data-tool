class UI::DetailSectionComponent < ViewComponent::Base
  def initialize(title:, rows: nil, data_available: true, column_labels: nil)
    @title = title
    @rows = rows
    @data_available = data_available
    @column_labels = column_labels
  end

  def rows?
    !@rows.nil?
  end
end
