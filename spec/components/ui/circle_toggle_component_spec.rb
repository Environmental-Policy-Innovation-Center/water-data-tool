require "rails_helper"

RSpec.describe UI::CircleToggleComponent, type: :component do
  subject(:component) { described_class.new(id: "my-toggle") }

  it "renders a checkbox input with the given id" do
    render_inline(component)
    expect(html.at_css("input[type=checkbox]#my-toggle")).to be_present
  end

  it "renders checked by default" do
    render_inline(component)
    expect(html.at_css("input")["checked"]).to eq("checked")
  end

  it "renders unchecked when checked: false" do
    render_inline(described_class.new(id: "my-toggle", checked: false))
    expect(html.at_css("input")["checked"]).to be_nil
  end

  it "renders both SVG states" do
    render_inline(component)
    expect(html.css("svg").count).to eq(2)
  end

  it "does not set data-action when omitted" do
    render_inline(component)
    expect(html.at_css("input")["data-action"]).to be_nil
  end

  context "with label" do
    subject(:component) { described_class.new(id: "my-toggle", label: "Select all") }

    it "renders a text label linked to the input" do
      render_inline(component)
      label = html.at_css("label[for='my-toggle']")
      expect(label).to be_present
      expect(label.text.strip).to eq("Select all")
    end

    it "gives the text label a derived id" do
      render_inline(component)
      expect(html.at_css("label[id='my-toggle-txt']")).to be_present
    end

    it "does not add aria-label to the input" do
      render_inline(component)
      expect(html.at_css("input")["aria-label"]).to be_nil
    end
  end

  context "icon-only with title" do
    subject(:component) { described_class.new(id: "my-toggle", title: "Toggle selection") }

    it "adds title to the wrapping label" do
      render_inline(component)
      expect(html.at_css("label[title='Toggle selection']")).to be_present
    end

    it "adds aria-label to the input for screen readers" do
      render_inline(component)
      expect(html.at_css("input")["aria-label"]).to eq("Toggle selection")
    end

    it "does not render a text label element" do
      render_inline(component)
      expect(html.css("label[for]")).to be_empty
    end
  end

  context "with data_action" do
    it "sets data-action on the input" do
      render_inline(described_class.new(id: "my-toggle", data_action: "change->filter#toggle"))
      expect(html.at_css("input")["data-action"]).to eq("change->filter#toggle")
    end
  end

  context "with input_classes" do
    it "merges additional classes onto the input" do
      render_inline(described_class.new(id: "my-toggle", input_classes: "select-all toggle"))
      cls = html.at_css("input")["class"]
      expect(cls).to include("select-all", "toggle")
    end

    it "preserves base input classes" do
      render_inline(described_class.new(id: "my-toggle", input_classes: "select-all"))
      cls = html.at_css("input")["class"]
      expect(cls).to include("peer", "absolute", "opacity-0")
    end
  end
end
