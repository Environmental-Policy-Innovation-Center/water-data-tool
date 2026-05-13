require "rails_helper"

RSpec.describe UI::MapRegionShortcutButtonComponent, type: :component do
  subject do
    render_inline described_class.new(
      label: "48",
      aria_label: "Zoom to 48 states",
      map_action: "zoom48"
    )
  end

  it "renders a single button" do
    subject
    expect(html.css("button").length).to eq(1)
  end

  it "sets label, aria-label, and map Stimulus action" do
    subject
    btn = html.at_css("button")
    expect(btn.text.strip).to eq("48")
    expect(btn["aria-label"]).to eq("Zoom to 48 states")
    expect(btn["data-action"]).to eq("click->map#zoom48")
  end

  it "renders as a standard-size circle" do
    subject
    cls = html.at_css("button")["class"]
    expect(cls).to include("w-8")
    expect(cls).to include("h-8")
    expect(cls).to include("rounded-full")
  end

  it "includes focus-visible ring" do
    subject
    expect(html.at_css("button")["class"]).to include("focus-visible:outline")
  end
end
