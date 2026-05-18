require "rails_helper"

RSpec.describe UI::ExternalLinkComponent, type: :component do
  subject(:component) { described_class.new(url: "https://example.com") }

  it "renders an anchor to the given url" do
    render_inline(component) { "Example" }
    expect(html.at_css("a")["href"]).to eq("https://example.com")
  end

  it "opens in a new tab" do
    render_inline(component) { "Example" }
    expect(html.at_css("a")["target"]).to eq("_blank")
    expect(html.at_css("a")["rel"]).to eq("noopener noreferrer")
  end

  it "has an opens-in-new-tab tooltip" do
    render_inline(component) { "Example" }
    expect(html.at_css("a")["title"]).to eq("Opens in new tab")
  end

  it "is underlined by default" do
    render_inline(component) { "Example" }
    expect(html.at_css("a")["class"]).to include("underline")
  end

  it "yields content inside the anchor" do
    render_inline(component) { "Example" }
    expect(html.at_css("a").text).to include("Example")
  end

  it "includes sr-only opens-in-new-tab text" do
    render_inline(component) { "Example" }
    expect(html.at_css(".sr-only").text).to eq("(opens in new tab)")
  end

  context "with aria_label" do
    subject(:component) { described_class.new(url: "https://example.com", aria_label: "Example site (opens in new tab)") }

    it "sets the aria-label" do
      render_inline(component) { "Example" }
      expect(html.at_css("a")["aria-label"]).to eq("Example site (opens in new tab)")
    end
  end

  context "without aria_label" do
    it "omits the aria-label attribute" do
      render_inline(component) { "Example" }
      expect(html.at_css("a")["aria-label"]).to be_nil
    end
  end

  context "with custom css_class" do
    subject(:component) { described_class.new(url: "https://example.com", css_class: "text-blue-600 underline") }

    it "applies the custom class" do
      render_inline(component) { "Example" }
      expect(html.at_css("a")["class"]).to eq("text-blue-600 underline")
    end
  end
end
