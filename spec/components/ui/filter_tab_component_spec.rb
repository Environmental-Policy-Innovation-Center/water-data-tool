require "rails_helper"

RSpec.describe UI::FilterTabComponent, type: :component do
  subject do
    render_inline described_class.new(menu_id: 1, label: "Source", li_id: "source-filter-button")
  end

  it "renders an li with the given id" do
    subject
    li = html.css("li").first
    expect(li).to be_present
    expect(li["id"]).to eq("source-filter-button")
  end

  it "sets filter class from menu_id" do
    subject
    expect(html.css("li").first["class"]).to include("filter-1")
  end

  it "renders count badge container with expected id fragment" do
    subject
    badge = html.css(".container-filter-count-menu-1").first
    expect(badge).to be_present
    expect(badge["aria-hidden"]).to eq("true")
  end

  it "renders count span with filter-count-group class" do
    subject
    span = html.css("span.filter-count-group-1").first
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
    expect(btn["data-menu"]).to eq("1")
    expect(btn["data-action"]).to eq("click->filter-menu#toggleMenu")
  end

  it "sets button id container-menu-btn-{menu_id}" do
    subject
    expect(html.css("button").first["id"]).to eq("container-menu-btn-1")
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

  it "includes focus-visible styles on the button" do
    subject
    expect(html.css("button").first["class"]).to include("focus-visible:outline")
  end
end
