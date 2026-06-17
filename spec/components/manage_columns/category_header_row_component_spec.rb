require "rails_helper"

RSpec.describe ManageColumns::CategoryHeaderRowComponent, type: :component do
  let(:cat) { CategoryDef.new(key: :violations, label: "Violations") }

  before do
    render_inline(described_class.new(cat: cat)) { "<li>child</li>".html_safe }
  end

  it "renders an li wrapper" do
    expect(html.at_css("li")).to be_present
  end

  it "renders the category label" do
    expect(html.text).to include("Violations")
  end

  it "renders a collapse toggle button with aria-expanded false (collapsed by default)" do
    btn = html.at_css("button[data-action='click->manage-columns#toggleCategoryCollapse']")
    expect(btn).to be_present
    expect(btn["aria-expanded"]).to eq("false")
    expect(btn["aria-controls"]).to eq("cat-body-violations")
  end

  it "renders a drag handle for reordering the category" do
    handle = html.at_css("button.drag-handle")
    expect(handle).to be_present
    expect(handle["aria-label"]).to eq("Drag to reorder Violations")
  end

  it "renders a toggle-all checkbox" do
    input = html.at_css("input[data-action='change->manage-columns#toggleCategory']")
    expect(input).to be_present
    expect(input["data-category"]).to eq("violations")
  end

  it "renders child content inside the body ul" do
    body = html.at_css("ul#cat-body-violations")
    expect(body).to be_present
    expect(body.text).to include("child")
  end

  it "renders the body ul with hidden class (collapsed by default)" do
    body = html.at_css("ul#cat-body-violations")
    expect(body["class"]).to include("hidden")
  end
end
