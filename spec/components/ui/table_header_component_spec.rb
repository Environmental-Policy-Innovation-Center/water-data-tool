require "rails_helper"

RSpec.describe UI::TableHeaderComponent, type: :component do
  describe "non-sortable column" do
    subject(:component) { described_class.new(label: "EPA Facility Report", size: :sm) }

    it "renders a th" do
      render_inline(component)
      expect(html.at_css("th")).to be_present
    end

    it "renders the label as plain text" do
      render_inline(component)
      expect(html.at_css("th").text.strip).to eq("EPA Facility Report")
    end

    it "does not render a sort link" do
      render_inline(component)
      expect(html.at_css("a")).to be_nil
    end

    it "does not have an aria-sort attribute" do
      render_inline(component)
      expect(html.at_css("th")["aria-sort"]).to be_nil
    end
  end

  describe "sortable column — unsorted" do
    subject(:component) { described_class.new(label: "Utility Name", column: "pws_name", size: :pinned) }

    it "has aria-sort=none" do
      with_request_url("/table") do
        render_inline(component)
        expect(html.at_css("th")["aria-sort"]).to eq("none")
      end
    end

    it "renders a sort link" do
      with_request_url("/table") do
        render_inline(component)
        expect(html.at_css("a")).to be_present
      end
    end

    it "sort link targets ascending" do
      with_request_url("/table") do
        render_inline(component)
        href = html.at_css("a")["href"]
        expect(href).to include("sort=pws_name")
        expect(href).to include("direction=asc")
      end
    end

    it "preserves other params in the sort URL" do
      with_request_url("/table?state=VT") do
        render_inline(component)
        expect(html.at_css("a")["href"]).to include("state=VT")
      end
    end
  end

  describe "sortable column — ascending" do
    subject(:component) { described_class.new(label: "Utility Name", column: "pws_name", size: :pinned) }

    it "has aria-sort=ascending" do
      with_request_url("/table?sort=pws_name&direction=asc") do
        render_inline(component)
        expect(html.at_css("th")["aria-sort"]).to eq("ascending")
      end
    end

    it "defaults to aria-sort=ascending when direction param is absent" do
      with_request_url("/table?sort=pws_name") do
        render_inline(component)
        expect(html.at_css("th")["aria-sort"]).to eq("ascending")
      end
    end

    it "sort link advances to descending" do
      with_request_url("/table?sort=pws_name&direction=asc") do
        render_inline(component)
        expect(html.at_css("a")["href"]).to include("direction=desc")
      end
    end
  end

  describe "sortable column — descending" do
    subject(:component) { described_class.new(label: "Utility Name", column: "pws_name", size: :pinned) }

    it "has aria-sort=descending" do
      with_request_url("/table?sort=pws_name&direction=desc") do
        render_inline(component)
        expect(html.at_css("th")["aria-sort"]).to eq("descending")
      end
    end

    it "sort link clears the sort" do
      with_request_url("/table?sort=pws_name&direction=desc") do
        render_inline(component)
        href = html.at_css("a")["href"]
        expect(href).not_to include("sort=")
        expect(href).not_to include("direction=")
      end
    end
  end

  describe "check column" do
    subject(:component) { described_class.new(size: :check) }

    it "renders a checkbox input" do
      render_inline(component)
      expect(html.at_css("input[type=checkbox]")).to be_present
    end

    it "has the selectAll Stimulus target" do
      render_inline(component)
      expect(html.at_css("input")["data-row-selection-target"]).to eq("selectAll")
    end

    it "has an accessible label on the checkbox" do
      render_inline(component)
      expect(html.at_css("input")["aria-label"]).to eq("Select all rows on this page")
    end

    it "does not have aria-sort on the th" do
      render_inline(component)
      expect(html.at_css("th")["aria-sort"]).to be_nil
    end
  end

  describe "size variants" do
    {
      default: "min-w-[10rem]",
      sm: "min-w-[8rem]",
      wide: "min-w-[14rem]",
      pinned: "min-w-[12rem]",
      check: "w-7"
    }.each do |size, expected_class|
      it "#{size} applies #{expected_class}" do
        render_inline(described_class.new(label: "Test", size: size))
        expect(html.at_css("th")["class"]).to include(expected_class)
      end
    end

    it "pinned applies left-7 for horizontal sticking" do
      render_inline(described_class.new(label: "Test", size: :pinned))
      expect(html.at_css("th")["class"]).to include("left-7")
    end
  end
end
