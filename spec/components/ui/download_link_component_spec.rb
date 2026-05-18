require "rails_helper"

RSpec.describe UI::DownloadLinkComponent, type: :component do
  subject(:component) { described_class.new(url: "https://example.com/file.zip") }

  it "renders an anchor to the given url" do
    render_inline(component) { "National" }
    expect(html.at_css("a")["href"]).to eq("https://example.com/file.zip")
  end

  it "opens in a new tab" do
    render_inline(component) { "National" }
    expect(html.at_css("a")["target"]).to eq("_blank")
    expect(html.at_css("a")["rel"]).to eq("noopener noreferrer")
  end

  it "has a download tooltip" do
    render_inline(component) { "National" }
    expect(html.at_css("a")["title"]).to eq("Download file")
  end

  it "has the download attribute" do
    render_inline(component) { "National" }
    expect(html.at_css("a")["download"]).not_to be_nil
  end

  it "includes sr-only download text" do
    render_inline(component) { "National" }
    expect(html.at_css(".sr-only").text).to eq("(download)")
  end

  it "yields content inside the anchor" do
    render_inline(component) { "National" }
    expect(html.at_css("a").text).to include("National")
  end

  context "with show_icon: true (default)" do
    it "renders the downloads icon" do
      render_inline(component) { "National" }
      expect(rendered_content).to include("svg")
    end
  end

  context "with show_icon: false" do
    subject(:component) { described_class.new(url: "https://example.com/file.zip", show_icon: false) }

    it "does not render the icon" do
      render_inline(component) { "National" }
      expect(html.css("svg")).to be_empty
    end
  end

  context "with custom css_class" do
    subject(:component) { described_class.new(url: "https://example.com/file.zip", css_class: "text-blue-600") }

    it "applies the custom class" do
      render_inline(component) { "National" }
      expect(html.at_css("a")["class"]).to eq("text-blue-600")
    end
  end
end
