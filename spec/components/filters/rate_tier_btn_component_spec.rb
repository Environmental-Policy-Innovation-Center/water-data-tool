require "rails_helper"

RSpec.describe Filters::RateTierBtnComponent, type: :component do
  def render_btn(**overrides)
    defaults = {id: "tier-flat", label: "Flat Rate"}
    render_inline described_class.new(**defaults.merge(overrides))
  end

  it "renders a button with the correct id" do
    render_btn
    expect(html.at_css("button#tier-flat")).to be_present
  end

  it "wires the Stimulus action" do
    render_btn
    expect(html.at_css("button")["data-action"]).to eq("click->filter#toggleRateTier")
  end

  it "includes the rate-tier-box JS hook class" do
    render_btn
    expect(html.at_css("button")["class"]).to include("rate-tier-box")
  end

  context ":middle position (default)" do
    before { render_btn }

    it "has no standalone border-l or radius classes" do
      classes = html.at_css("button")["class"].split
      expect(classes).not_to include("border-l")
      expect(classes).not_to include("rounded-l-[10px]")
      expect(classes).not_to include("rounded-r-[10px]")
    end
  end

  context ":first position" do
    before { render_btn(position: :first) }

    it "adds left border and left radius" do
      classes = html.at_css("button")["class"]
      expect(classes).to include("border-l")
      expect(classes).to include("rounded-l-[10px]")
    end

    it "does not add right radius" do
      expect(html.at_css("button")["class"]).not_to include("rounded-r")
    end
  end

  context ":last position" do
    before { render_btn(position: :last) }

    it "adds right radius" do
      expect(html.at_css("button")["class"]).to include("rounded-r-[10px]")
    end

    it "does not add left border or left radius" do
      classes = html.at_css("button")["class"].split
      expect(classes).not_to include("rounded-l-[10px]")
      expect(classes).not_to include("border-l")
    end
  end
end
