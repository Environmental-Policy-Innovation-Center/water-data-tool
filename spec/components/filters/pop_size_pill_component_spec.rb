require "rails_helper"

RSpec.describe Filters::PopSizePillComponent, type: :component do
  def render_pill(**overrides)
    defaults = {id: "pop-medium", label: "Medium", sublabel: "3,301 - 10,000", pop_number: 3}
    render_inline described_class.new(**defaults.merge(overrides))
  end

  shared_examples "a valid pop size pill" do |id:, label:, sublabel:, pop_number:|
    it "renders a button with the correct id" do
      expect(html.css("button[id='#{id}']")).not_to be_empty
    end

    it "wires the Stimulus action" do
      expect(html.css("button").first["data-action"]).to eq("click->filter#togglePopSize")
    end

    it "includes required JS hook classes" do
      classes = html.css("button").first["class"]
      expect(classes).to include("pop-size-box")
      expect(classes).to include("pop-size-#{pop_number}")
    end

    it "renders the label and sublabel" do
      expect(rendered_content).to include(label)
      span = html.css("button span").first
      expect(span["class"]).to include("block")
      expect(span.text).to include(sublabel)
    end
  end

  context "middle pill (default position)" do
    before { render_pill }

    include_examples "a valid pop size pill",
      id: "pop-medium", label: "Medium", sublabel: "3,301 - 10,000", pop_number: 3

    it "has no radius classes" do
      classes = html.css("button").first["class"]
      expect(classes).not_to include("rounded-l")
      expect(classes).not_to include("rounded-r")
    end
  end

  context "first pill" do
    before { render_pill(id: "pop-very-small", label: "Very small", sublabel: "500 or less", pop_number: 1, position: :first) }

    include_examples "a valid pop size pill",
      id: "pop-very-small", label: "Very small", sublabel: "500 or less", pop_number: 1

    it "has a left border and left radius" do
      classes = html.css("button").first["class"]
      expect(classes).to include("border-l")
      expect(classes).to include("rounded-l-[10px]")
    end

    it "does not have right radius" do
      expect(html.css("button").first["class"]).not_to include("rounded-r")
    end
  end

  context "last pill" do
    before { render_pill(id: "pop-very-large", label: "Very large", sublabel: "100,000+", pop_number: 5, position: :last) }

    include_examples "a valid pop size pill",
      id: "pop-very-large", label: "Very large", sublabel: "100,000+", pop_number: 5

    it "has right radius" do
      expect(html.css("button").first["class"]).to include("rounded-r-[10px]")
    end

    it "does not have left radius" do
      expect(html.css("button").first["class"]).not_to include("rounded-l")
    end
  end
end
