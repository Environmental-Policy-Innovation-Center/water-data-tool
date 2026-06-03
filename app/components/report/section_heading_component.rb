class Report::SectionHeadingComponent < ViewComponent::Base
  def initialize(title:, column_labels: nil)
    @title = title
    @column_labels = column_labels
  end

  def column_labels?
    @column_labels.present?
  end
end
