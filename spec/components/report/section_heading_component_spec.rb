require "rails_helper"

RSpec.describe Report::SectionHeadingComponent, type: :component do
  it "renders a section title" do
    render_inline described_class.new(title: "Overview")

    expect(html.css("h3").text).to include("Overview")
  end

  it "renders column labels beside the title when provided" do
    render_inline described_class.new(title: "Violations", column_labels: ["5-Year", "10-Year"])

    expect(html.css("h3").text).to include("Violations")
    expect(rendered_content).to include("5-Year")
    expect(rendered_content).to include("10-Year")
  end
end
