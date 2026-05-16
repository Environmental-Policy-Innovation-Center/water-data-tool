require "rails_helper"

RSpec.describe UI::DatasetCardComponent, type: :component do
  let(:defaults) do
    {
      title: "Safe Drinking Water Information System",
      source: "epa",
      source_name: "U.S. Environmental Protection Agency (EPA)",
      source_url: "https://www.epa.gov/sdwis",
      frequency: "quarterly",
      date: "2026-02-20",
      description: "Water system violation and enforcement data.",
      caveats: ["Violations are known to be underreported", "Data may vary by state"]
    }
  end

  it "renders the title" do
    render_inline described_class.new(**defaults)
    expect(html.css("h2").text).to include("Safe Drinking Water Information System")
  end

  it "renders the description" do
    render_inline described_class.new(**defaults)
    expect(rendered_content).to include("Water system violation and enforcement data.")
  end

  it "renders the source link" do
    render_inline described_class.new(**defaults)
    link = html.css("a").first
    expect(link.text).to include("U.S. Environmental Protection Agency")
    expect(link["href"]).to eq("https://www.epa.gov/sdwis")
    expect(link["target"]).to eq("_blank")
    expect(link["rel"]).to eq("noopener noreferrer")
  end

  it "formats date as m/d/yyyy" do
    render_inline described_class.new(**defaults)
    expect(rendered_content).to include("2/20/2026")
  end

  it "capitalizes frequency label" do
    render_inline described_class.new(**defaults.merge(frequency: "annually"))
    expect(rendered_content).to include("Annually")
  end

  it "renders all caveats as list items" do
    render_inline described_class.new(**defaults)
    items = html.css("li").map(&:text)
    expect(items).to include("Violations are known to be underreported")
    expect(items).to include("Data may vary by state")
  end

  it "sets data attributes for JS filtering" do
    render_inline described_class.new(**defaults)
    wrapper = html.css(".grid-item").first
    expect(wrapper["data-source"]).to eq("epa")
    expect(wrapper["data-frequency"]).to eq("quarterly")
    expect(wrapper["data-date"]).to eq("2026-02-20")
  end

  it "mounts the dataset-card Stimulus controller on the card border" do
    render_inline described_class.new(**defaults)
    card = html.css("[data-controller='dataset-card']").first
    expect(card).to be_present
  end

  it "marks the content area as the Stimulus content target with collapsed state" do
    render_inline described_class.new(**defaults)
    content = html.css("[data-dataset-card-target='content']").first
    expect(content).to be_present
    expect(content["data-collapsed"]).to eq("true")
  end

  it "renders a sentinel for clip detection at the end of the body" do
    render_inline described_class.new(**defaults)
    sentinel = html.css("[data-dataset-card-target='sentinel']").first
    expect(sentinel).to be_present
    expect(sentinel["aria-hidden"]).to eq("true")
  end

  it "renders a show-more / show-less toggle (hidden until overflow)" do
    render_inline described_class.new(**defaults)
    button = html.css("[data-dataset-card-target='toggle']").first
    expect(button).to be_present
    expect(button["type"]).to eq("button")
    expect(button["data-action"]).to eq("click->dataset-card#toggle")
    expect(button.text.strip).to eq("show more")
    # Boolean `hidden` serializes as empty string in HTML — check attribute presence, not value truthiness
    expect(button.has_attribute?("hidden")).to be true
  end
end
