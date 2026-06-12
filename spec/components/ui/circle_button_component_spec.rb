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

  context "with label: and label_position: :left" do
    subject(:component) do
      described_class.new(aria_label: "Toggle all", label: "Deselect all", label_position: :left)
    end

    it "renders label text to the left of the circle" do
      render_inline(component) { "X" }
      children = html.at_css("button").children.select(&:element?)
      expect(children.first.text.strip).to eq("Deselect all")
    end

    it "does not apply circle sizing classes to the button itself" do
      render_inline(component) { "X" }
      expect(html.at_css("button")["class"]).not_to include("w-8")
    end

    it "uses inline-flex layout on the button" do
      render_inline(component) { "X" }
      expect(html.at_css("button")["class"]).to include("inline-flex", "items-center", "gap-2")
    end

    it "adds id to label span when id is given" do
      component = described_class.new(
        aria_label: "Toggle all", id: "my-btn", label: "Deselect all", label_position: :left
      )
      render_inline(component) { "X" }
      expect(html.at_css("#my-btn-label")).to be_present
      expect(html.at_css("#my-btn-label").text).to eq("Deselect all")
    end
  end

  context "with label: and label_position: :right" do
    subject(:component) do
      described_class.new(aria_label: "Toggle all", label: "Select all", label_position: :right)
    end

    it "renders label text to the right of the circle" do
      render_inline(component) { "X" }
      children = html.at_css("button").children.select(&:element?)
      expect(children.last.text.strip).to eq("Select all")
    end
  end

  context "with optional attributes" do
    subject(:component) do
      described_class.new(
        aria_label: "Print",
        id: "tt-print-report",
        data_action: "click->report#print",
        classes: "fixed top-[30px] right-20"
      )
    end

    it "sets id and data-action" do
      render_inline(component) { "" }
      btn = html.at_css("button")
      expect(btn["id"]).to eq("tt-print-report")
      expect(btn["data-action"]).to eq("click->report#print")
    end

    it "merges classes with base classes" do
      render_inline(component) { "" }
      cls = html.at_css("button")["class"]
      expect(cls).to include("fixed", "top-[30px]", "right-20", "w-8")
    end
  end
end
