require "rails_helper"

RSpec.describe Filters::CategoryComponent, type: :component do
  subject(:component) { described_class.new(label: "Violations") }

  it "renders an h3 with the given label" do
    render_inline(component)
    expect(html.at_css("h3").text.strip).to eq("Violations")
  end

  it "applies base heading classes" do
    render_inline(component)
    cls = html.at_css("h3")["class"]
    expect(cls).to include("m-0")
    expect(cls).to include("px-[15px]")
    expect(cls).to include("py-5")
    expect(cls).to include("text-base")
  end

  context "default variant" do
    it "applies white-on-gray heading styles" do
      render_inline(component)
      cls = html.at_css("h3")["class"]
      expect(cls).to include("text-white")
      expect(cls).to include("bg-[#989898]")
      expect(cls).to include("font-medium")
    end

    it "includes More-panel contextual overrides for auto-switch to light styling" do
      render_inline(component)
      cls = html.at_css("h3")["class"]
      expect(cls).to include("[.filter-dropdown-more_&]:font-bold")
      expect(cls).to include("[.filter-dropdown-more_&]:text-neutral-900")
      expect(cls).to include("[.filter-dropdown-more_&]:bg-white")
    end

    it "includes More-panel padding overrides to tighten heading spacing in the More menu" do
      render_inline(component)
      cls = html.at_css("h3")["class"]
      expect(cls).to include("[.filter-dropdown-more_&]:pt-3")
      expect(cls).to include("[.filter-dropdown-more_&]:pb-0")
    end
  end

  context "light variant" do
    subject(:component) { described_class.new(label: "Financial", variant: :light) }

    it "applies dark-on-white heading styles" do
      render_inline(component)
      cls = html.at_css("h3")["class"]
      expect(cls).to include("text-neutral-900")
      expect(cls).to include("bg-white")
      expect(cls).to include("font-bold")
    end
  end

  context "without tooltip_text" do
    it "renders no tooltip icon" do
      render_inline(component)
      expect(html.at_css("[data-controller='tooltip']")).to be_nil
    end
  end

  context "with tooltip_text" do
    subject(:component) { described_class.new(label: "Violations", tooltip_text: "Some tooltip copy") }

    it "renders a tooltip span inside the heading" do
      render_inline(component)
      span = html.at_css("h3 [data-controller='tooltip']")
      expect(span).to be_present
      expect(span["data-tooltip-text-value"]).to eq("Some tooltip copy")
    end

    it "includes mouseenter/mouseleave actions" do
      render_inline(component)
      span = html.at_css("h3 [data-controller='tooltip']")
      expect(span["data-action"]).to include("mouseenter->tooltip#show")
      expect(span["data-action"]).to include("mouseleave->tooltip#hide")
    end
  end

  it "yields content after the heading" do
    render_inline(component) { '<ul class="inner"><li>Item</li></ul>'.html_safe }
    expect(html.at_css("ul.inner")).to be_present
    body = rendered_content
    expect(body.index("h3")).to be < body.index("inner")
  end
end
