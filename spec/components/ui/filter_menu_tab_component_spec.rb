require "rails_helper"

RSpec.describe UI::FilterMenuTabComponent, type: :component do
  subject do
    render_inline described_class.new(menu_key: "source", label: "Source")
  end

  it "renders an li with id derived from menu_key" do
    subject
    li = html.css("li").first
    expect(li).to be_present
    expect(li["id"]).to eq("filter-tab-source")
  end

  it "sets filter class from menu_key" do
    subject
    expect(html.css("li").first["class"]).to include("filter-source")
  end

  it "renders count badge container with expected id fragment" do
    subject
    badge = html.css(".container-filter-count-menu-source").first
    expect(badge).to be_present
    expect(badge["aria-hidden"]).to eq("true")
  end

  it "renders count span with filter-count-group class" do
    subject
    span = html.css("span.filter-count-group-source").first
    expect(span).to be_present
    expect(span.text.strip).to eq("0")
  end

  it "renders a filter trigger button" do
    subject
    btn = html.css("button.filter-menu-btn").first
    expect(btn).to be_present
    expect(btn["type"]).to eq("button")
  end

  it "sets aria-expanded and aria-haspopup on the button" do
    subject
    btn = html.css("button").first
    expect(btn["aria-expanded"]).to eq("false")
    expect(btn["aria-haspopup"]).to eq("true")
  end

  it "sets data-menu and Stimulus action" do
    subject
    btn = html.css("button").first
    expect(btn["data-menu"]).to eq("source")
    expect(btn["data-action"]).to eq("click->filter-menu#toggleMenu")
  end

  it "sets button id container-menu-btn-{menu_key}" do
    subject
    expect(html.css("button").first["id"]).to eq("container-menu-btn-source")
  end

  it "uses w-auto instead of fixed pixel width" do
    subject
    expect(html.css("button").first["class"]).to include("w-auto")
    expect(html.css("button").first["class"]).not_to include("w-[122px]")
  end

  it "renders the visible label in a flex-1 span" do
    subject
    span = html.css("button span.flex-1").first
    expect(span).to be_present
    expect(span.text.strip).to eq("Source")
  end

  context "with a mobile_label" do
    subject do
      render_inline described_class.new(menu_key: "more", label: "More", mobile_label: "Filters")
    end

    it "renders the desktop label hidden on mobile" do
      subject
      desktop_span = html.css("button span.flex-1").find { |s| s.text.strip == "More" }
      expect(desktop_span).to be_present
      expect(desktop_span["class"]).to include("hidden")
      expect(desktop_span["class"]).to include("sm:inline")
    end

    it "renders the mobile label visible only below sm breakpoint" do
      subject
      mobile_span = html.css("button span.flex-1").find { |s| s.text.strip == "Filters" }
      expect(mobile_span).to be_present
      expect(mobile_span["class"]).to include("sm:hidden")
    end
  end

  it "includes focus-visible styles on the button" do
    subject
    expect(html.css("button").first["class"]).to include("focus-visible:outline")
  end
end
