require "rails_helper"

RSpec.describe UI::NavItemComponent, type: :component do
  describe "button variant (no href)" do
    subject do
      render_inline described_class.new(section: "map", label: "Explore the Map", icon_name: "explore")
    end

    it "renders a button element with type=button" do
      subject
      btn = html.css("button").first
      expect(btn).to be_present
      expect(btn["type"]).to eq("button")
    end

    it "has an aria-label matching the label text" do
      subject
      expect(html.css("button").first["aria-label"]).to eq("Explore the Map")
    end

    it "sets data-section" do
      subject
      expect(html.css("button").first["data-section"]).to eq("map")
    end

    it "sets data-action for nav controller" do
      subject
      expect(html.css("button").first["data-action"]).to eq("click->nav#show")
    end

    it "includes nav-item base classes" do
      subject
      btn = html.css("button").first
      expect(btn["class"]).to include("nav-item")
      expect(btn["class"]).to include("flex")
      expect(btn["class"]).to include("rounded-full")
    end

    it "does not include active class by default" do
      subject
      expect(html.css("button").first["class"].split).not_to include("active")
    end

    it "does not set aria-current by default" do
      subject
      expect(html.css("button").first["aria-current"]).to be_nil
    end

    it "renders the label inside a collapsible span" do
      subject
      span = html.css("span").find { |s| s.text.strip == "Explore the Map" }
      expect(span).to be_present
      expect(span["class"]).to include("group-data-[sidebar-collapsed]:hidden")
    end
  end

  describe "active: true" do
    subject do
      render_inline described_class.new(section: "map", label: "Explore the Map", icon_name: "explore", active: true)
    end

    it "adds the active class to the button" do
      subject
      expect(html.css("button").first["class"].split).to include("active")
    end

    it "sets aria-current=page" do
      subject
      expect(html.css("button").first["aria-current"]).to eq("page")
    end
  end

  describe "link variant (href present)" do
    subject do
      render_inline described_class.new(
        label: "Documentation",
        icon_name: "documentation",
        href: "https://example.com/doc"
      )
    end

    it "renders an anchor element" do
      subject
      expect(html.css("a").first).to be_present
    end

    it "has an aria-label matching the label text" do
      subject
      expect(html.css("a").first["aria-label"]).to eq("Documentation")
    end

    it "sets the href" do
      subject
      expect(html.css("a").first["href"]).to eq("https://example.com/doc")
    end

    it "includes nav-item base classes" do
      subject
      expect(html.css("a").first["class"]).to include("nav-item")
      expect(html.css("a").first["class"]).to include("no-underline")
    end

    it "does not have data-section or data-action" do
      subject
      link = html.css("a").first
      expect(link["data-section"]).to be_nil
      expect(link["data-action"]).to be_nil
    end

    it "renders the label inside a collapsible span" do
      subject
      span = html.css("span").find { |s| s.text.strip == "Documentation" }
      expect(span).to be_present
      expect(span["class"]).to include("group-data-[sidebar-collapsed]:hidden")
    end
  end

  describe "external: true" do
    subject do
      render_inline described_class.new(
        label: "Documentation",
        icon_name: "documentation",
        href: "https://example.com/doc",
        external: true
      )
    end

    it "adds target=_blank" do
      subject
      expect(html.css("a").first["target"]).to eq("_blank")
    end

    it "adds rel=noopener noreferrer" do
      subject
      expect(html.css("a").first["rel"]).to eq("noopener noreferrer")
    end

    it "adds title for new-tab disclosure" do
      subject
      expect(html.css("a").first["title"]).to eq("Opens in new tab")
    end

    it "renders a sr-only span disclosing the new-tab behaviour" do
      subject
      sr = html.css(".sr-only").first
      expect(sr).to be_present
      expect(sr.text).to include("opens in new tab")
    end

    it "appends (opens in new tab) to aria-label" do
      subject
      expect(html.css("a").first["aria-label"]).to eq("Documentation (opens in new tab)")
    end
  end
end
