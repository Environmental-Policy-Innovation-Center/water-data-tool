require "rails_helper"

RSpec.describe UI::FilterMenuPanelComponent, type: :component do
  describe "default menu (main filter group)" do
    subject do
      render_inline(described_class.new(menu_key: "source")) do
        '<div id="container-menu-source-items"><p class="inner">Items</p></div>'.html_safe
      end
    end

    it "renders outer container with expected id and filter-dropdown class" do
      subject
      root = html.css("div#container-menu-source").first
      expect(root).to be_present
      expect(root["class"]).to include("filter-dropdown")
    end

    it "starts hidden for filter_menu_controller visibility toggling" do
      subject
      expect(html.css("div#container-menu-source").first["class"]).to include("hidden")
    end

    it "applies max-height cap via Tailwind arbitrary class" do
      subject
      expect(html.css("div#container-menu-source").first["class"]).to include("max-h-[calc(100vh-350px)]")
    end

    it "scopes scrollbar hooks for WebKit (class) and overflow" do
      subject
      cls = html.css("div#container-menu-source").first["class"]
      expect(cls).to include("filter-menu-scroll")
      expect(cls).to include("overflow-y-auto")
    end

    it "renders main-filter-grp placeholder before yielded content" do
      subject
      body = rendered_content
      expect(body.index("main-filter-grp-source")).to be < body.index("container-menu-source-items")
    end

    it "yields block content inside the shell" do
      subject
      expect(html.at_css("p.inner").text).to eq("Items")
    end

    it "renders sticky footer with Reset and Apply" do
      subject
      footer = html.at_css('[aria-label="Filter actions"]')
      expect(footer).to be_present
      buttons = footer.css("button")
      expect(buttons.map { |b| b.text.strip }).to eq(["Reset", "Apply"])
    end

    it "wires Reset to filter#reset and Apply to filter#apply" do
      subject
      footer = html.at_css('[aria-label="Filter actions"]')
      expect(footer.css("button").first["data-action"]).to eq("click->filter#reset")
      expect(footer.css("button").last["data-action"]).to eq("click->filter#apply")
    end
  end

  describe "more menu variant" do
    subject do
      render_inline(
        described_class.new(
          menu_key: "more",
          more_menu: true,
          reset_data_action: "click->filter#resetAll",
          reset_label: "Reset All"
        )
      ) do
        "<div id=\"container-menu-more-items\"></div>".html_safe
      end
    end

    it "adds filter-dropdown-more class" do
      subject
      expect(html.css("div#container-menu-more").first["class"]).to include("filter-dropdown-more")
    end

    it "does not render main-filter-grp placeholder" do
      subject
      expect(html.at_css("#main-filter-grp-more")).to be_nil
    end

    it "uses custom reset action and label" do
      subject
      footer = html.at_css('[aria-label="Filter actions"]')
      reset = footer.css("button").first
      expect(reset["data-action"]).to eq("click->filter#resetAll")
      expect(reset.text.strip).to eq("Reset All")
    end

    it "applies mobile positioning classes that override the desktop min-width" do
      subject
      cls = html.css("div#container-menu-more").first["class"]
      expect(cls).to include("max-sm:!min-w-0")
      expect(cls).to include("max-sm:left-2")
      expect(cls).to include("max-sm:right-2")
      expect(cls).to include("max-sm:w-auto")
    end
  end
end
