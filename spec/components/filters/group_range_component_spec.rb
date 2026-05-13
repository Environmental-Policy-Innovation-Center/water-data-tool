require "rails_helper"

RSpec.describe Filters::GroupRangeComponent, type: :component do
  let(:base_args) do
    {
      checkbox_id: "more-poverty-rate",
      panel_id: "subcat-poverty-rate",
      label: "Poverty rate",
      tooltip_text: "Poverty rate is the percentage of households below the federal poverty level.",
      field: "poverty_rate",
      min_input_id: "min-poverty-rate",
      max_input_id: "max-poverty-rate",
      slider_label: "% of households"
    }
  end

  shared_examples "renders a range filter item" do
    it "renders a list item" do
      expect(html.css("li")).to be_present
    end

    it "applies filter menu row utilities on the list item" do
      li = html.css("li").first
      expect(li["class"]).to include("hover:bg-neutral-50")
    end

    it "renders the label" do
      label = html.css("label").first
      expect(label["for"]).to eq("more-poverty-rate")
      expect(label.text).to eq("Poverty rate")
    end

    it "renders the tooltip span" do
      span = html.css("[data-controller='tooltip']").first
      expect(span["data-tooltip-text-value"]).to include("Poverty rate is the percentage")
      expect(span["data-action"]).to include("mouseenter->tooltip#show")
    end

    it "renders the expand button wired to the panel" do
      button = html.css("button").first
      expect(button["data-action"]).to eq("click->filter#toggleSubcatPanel")
      expect(button["data-panel-id"]).to eq("subcat-poverty-rate")
      expect(button["aria-expanded"]).to eq("false")
      expect(button["aria-controls"]).to eq("subcat-poverty-rate")
    end

    it "renders the slider panel with correct ids" do
      panel = html.css("[data-controller='slider']").first
      expect(panel["id"]).to eq("subcat-poverty-rate")
      expect(panel["data-slider-field-value"]).to eq("poverty_rate")
      expect(html.css("input[id='min-poverty-rate']")).to be_present
      expect(html.css("input[id='max-poverty-rate']")).to be_present
    end

    it "renders the slider label" do
      expect(rendered_content).to include("% of households")
    end
  end

  context "when nested: false (default — top-level filter item)" do
    before { render_inline described_class.new(**base_args) }

    include_examples "renders a range filter item"

    it "has a flat layout with no flex wrapper" do
      expect(html.css(".flex.items-center.justify-between")).to be_empty
    end

    it "wires the checkbox to toggleSubcat with data-panel-id" do
      checkbox = html.css("input[type='checkbox']").first
      expect(checkbox["id"]).to eq("more-poverty-rate")
      expect(checkbox["data-action"]).to eq("change->filter#toggleSubcat")
      expect(checkbox["data-panel-id"]).to eq("subcat-poverty-rate")
    end

    it "uses a smaller arrow icon (h-3 w-3)" do
      expect(rendered_content).to include("h-3 w-3")
    end
  end

  context "when nested: true (subcat item inside a subcat panel)" do
    before { render_inline described_class.new(**base_args, nested: true) }

    include_examples "renders a range filter item"

    it "wraps label row in a flex justify-between div" do
      expect(html.css(".flex.items-center.justify-between")).to be_present
    end

    it "renders the checkbox without toggleSubcat data attributes" do
      checkbox = html.css("input[type='checkbox']").first
      expect(checkbox["id"]).to eq("more-poverty-rate")
      expect(checkbox["data-action"]).to be_nil
      expect(checkbox["data-panel-id"]).to be_nil
    end

    it "uses a larger arrow icon (h-3.5 w-3.5)" do
      expect(rendered_content).to include("h-3.5 w-3.5")
    end
  end

  context "slider_label default" do
    it "defaults to 'Number of violations' when not provided" do
      render_inline described_class.new(**base_args.except(:slider_label))
      expect(rendered_content).to include("Number of violations")
    end
  end

  context "when format is provided" do
    before { render_inline described_class.new(**base_args, format: "percent") }

    it "sets data-slider-format-value on the slider panel" do
      panel = html.css("[data-controller='slider']").first
      expect(panel["data-slider-format-value"]).to eq("percent")
    end
  end

  context "when format is not provided" do
    before { render_inline described_class.new(**base_args) }

    it "omits data-slider-format-value from the slider panel" do
      panel = html.css("[data-controller='slider']").first
      expect(panel["data-slider-format-value"]).to be_nil
    end
  end

  context "when format is 'percent_change'" do
    before { render_inline described_class.new(**base_args, format: "percent_change") }

    it "renders the zero label target in the slider panel" do
      expect(html.css("[data-slider-target~='zeroLabel']")).to be_present
    end

    it "sets data-slider-format-value to percent_change" do
      panel = html.css("[data-controller='slider']").first
      expect(panel["data-slider-format-value"]).to eq("percent_change")
    end
  end
end
