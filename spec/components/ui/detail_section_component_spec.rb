require "rails_helper"

RSpec.describe UI::DetailSectionComponent, type: :component do
  it "renders the title" do
    render_inline described_class.new(title: "Water Source", rows: [{label: "Type", value: "Groundwater"}])
    expect(html.css("h3").text).to include("Water Source")
  end

  it "renders label-value rows" do
    render_inline described_class.new(
      title: "Overview",
      rows: [
        {label: "Population", value: "5,000"},
        {label: "Source", value: "Surface Water"}
      ]
    )
    cell_texts = html.css("td").map(&:text)
    expect(cell_texts).to include("Population", "5,000", "Source", "Surface Water")
  end

  it "renders no table cells for empty rows" do
    render_inline described_class.new(title: "Empty", rows: [])
    expect(html.css("h3").text).to include("Empty")
    expect(html.css("td")).to be_empty
  end

  it "renders data not available message when data_available is false" do
    render_inline described_class.new(title: "Trends", data_available: false)
    expect(rendered_content).to include("Data not available")
    expect(html.css("table")).to be_empty
  end

  it "renders content block when no rows are given" do
    render_inline(described_class.new(title: "Violations")) do
      "<table><tr><td>Custom</td></tr></table>".html_safe
    end
    expect(html.css("h3").text).to include("Violations")
    expect(html.css("td").text).to include("Custom")
  end

  it "renders column labels inline with the title when column_labels are provided" do
    render_inline described_class.new(title: "Violations", column_labels: ["5-Year", "10-Year"])
    expect(html.css("h3").text).to include("Violations")
    expect(rendered_content).to include("5-Year")
    expect(rendered_content).to include("10-Year")
  end

  it "does not render table when data_available is false, even with rows" do
    render_inline described_class.new(
      title: "Funding",
      rows: [{label: "Amount", value: "$1,000"}],
      data_available: false
    )
    expect(html.css("table")).to be_empty
  end
end
