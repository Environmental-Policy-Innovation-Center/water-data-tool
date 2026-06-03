class Report::SectionHeadingComponentPreview < Lookbook::Preview
  def default
    render Report::SectionHeadingComponent.new(title: "Overview")
  end

  def with_column_labels
    render Report::SectionHeadingComponent.new(
      title: "Violations",
      column_labels: ["5-Year", "10-Year"]
    )
  end
end
