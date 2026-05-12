require "rails_helper"

RSpec.describe UI::MapRegionShortcutButtonComponent, type: :component do
  describe "state shortcut (e.g. 48)" do
    subject do
      render_inline described_class.new(
        label: "48",
        aria_label: "Zoom to 48 states",
        map_action: "zoom48",
        territory: false
      )
    end

    it "renders a single button" do
      subject
      expect(html.css("button").length).to eq(1)
    end

    it "sets label, title, aria-label, and map Stimulus action" do
      subject
      btn = html.at_css("button")
      expect(btn.text.strip).to eq("48")
      expect(btn["title"]).to eq("Zoom to 48 states")
      expect(btn["aria-label"]).to eq("Zoom to 48 states")
      expect(btn["data-action"]).to eq("click->map#zoom48")
    end

    it "uses state text styling" do
      subject
      expect(html.at_css("button")["class"]).to include("text-[0.8em]")
      expect(html.at_css("button")["class"]).to include("text-[#333]")
    end

    it "includes focus-visible ring and legacy padding" do
      subject
      cls = html.at_css("button")["class"]
      expect(cls).to include("p-1.5")
      expect(cls).to include("focus-visible:outline")
    end
  end

  describe "territory shortcut (e.g. PR)" do
    subject do
      render_inline described_class.new(
        label: "PR",
        aria_label: "Zoom to Puerto Rico (territory)",
        map_action: "zoomPr",
        territory: true
      )
    end

    it "uses territory text styling" do
      subject
      cls = html.at_css("button")["class"]
      expect(cls).to include("text-[0.72em]")
      expect(cls).to include("text-[#666]")
    end
  end
end
