require "rails_helper"

RSpec.describe UI::CircleButtonComponent, type: :component do
  subject(:component) { described_class.new(aria_label: "Close") }

  it "renders a button with the given aria-label" do
    render_inline(component) { "X" }
    btn = html.at_css("button")
    expect(btn).to be_present
    expect(btn["aria-label"]).to eq("Close")
    expect(btn["type"]).to eq("button")
  end

  it "yields content inside the button" do
    render_inline(component) { "X" }
    expect(html.at_css("button").text.strip).to eq("X")
  end

  it "applies base circle classes" do
    render_inline(component) { "" }
    cls = html.at_css("button")["class"]
    expect(cls).to include("flex")
    expect(cls).to include("items-center")
    expect(cls).to include("justify-center")
    expect(cls).to include("w-8")
    expect(cls).to include("h-8")
    expect(cls).to include("rounded-full")
  end

  it "includes focus-visible ring" do
    render_inline(component) { "" }
    expect(html.at_css("button")["class"]).to include("focus-visible:outline")
  end

  it "does not render id or data-action when omitted" do
    render_inline(component) { "" }
    btn = html.at_css("button")
    expect(btn["id"]).to be_nil
    expect(btn["data-action"]).to be_nil
  end

  context "with optional attributes" do
    subject(:component) do
      described_class.new(
        aria_label: "Print",
        id: "tt-print-report",
        data_action: "click->report#print",
        extra_classes: "fixed top-[30px] right-20"
      )
    end

    it "sets id and data-action" do
      render_inline(component) { "" }
      btn = html.at_css("button")
      expect(btn["id"]).to eq("tt-print-report")
      expect(btn["data-action"]).to eq("click->report#print")
    end

    it "appends extra_classes to base classes" do
      render_inline(component) { "" }
      cls = html.at_css("button")["class"]
      expect(cls).to include("fixed")
      expect(cls).to include("top-[30px]")
      expect(cls).to include("right-20")
      expect(cls).to include("w-8")
    end
  end
end
