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

  it "always applies structural base classes" do
    render_inline(component) { "Example" }
    expect(html.at_css("a")["class"]).to include("inline-flex", "items-center", "gap-0.5")
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

  it "does not set aria-label by default" do
    render_inline(component) { "Example" }
    expect(html.at_css("a")["aria-label"]).to be_nil
  end

  context "with aria_label:" do
    subject(:component) { described_class.new(url: "https://example.com", aria_label: "Example site") }

    it "sets aria-label on the anchor" do
      render_inline(component) { "Example" }
      expect(html.at_css("a")["aria-label"]).to eq("Example site")
    end
  end

  it "renders the external-link icon by default" do
    render_inline(component) { "Example" }
    expect(html.at_css("a svg")).to be_present
  end

  context "with show_icon: false" do
    subject(:component) { described_class.new(url: "https://example.com", show_icon: false) }

    it "omits the icon" do
      render_inline(component) { "Example" }
      expect(html.at_css("a svg")).to be_nil
    end
  end

  context "with underline: false" do
    subject(:component) { described_class.new(url: "https://example.com", underline: false) }

    it "omits the underline class" do
      render_inline(component) { "Example" }
      expect(html.at_css("a")["class"].split).not_to include("underline")
    end

    it "retains structural classes" do
      render_inline(component) { "Example" }
      expect(html.at_css("a")["class"]).to include("inline-flex", "items-center")
    end
  end

  context "with custom classes" do
    subject(:component) { described_class.new(url: "https://example.com", classes: "text-blue-600") }

    it "merges custom class with base classes" do
      render_inline(component) { "Example" }
      expect(html.at_css("a")["class"]).to include("inline-flex", "items-center", "gap-0.5", "text-blue-600")
    end
  end
end
