require "rails_helper"

RSpec.describe ManageColumns::PinnedRowComponent, type: :component do
  let(:col) do
    TableColumn.new(
      key: :pws_name, label: "Utility Name", sort: "pws_name", format: :str,
      format_opts: {}, size: :pinned, row_header: true, pinned: true,
      source: :pws, csv_label: "Utility Name", sql_expr: "pws.pws_name", category: nil
    )
  end

  before { render_inline(described_class.new(col: col)) }

  it "renders an li" do
    expect(html.at_css("li")).to be_present
  end

  it "renders the column label" do
    expect(html.text).to include("Utility Name")
  end

  it "renders a disabled checked checkbox" do
    input = html.at_css("input[type='checkbox']")
    expect(input["checked"]).to be_present
    expect(input["disabled"]).to be_present
  end

  it "includes an aria-label on the checkbox" do
    input = html.at_css("input[type='checkbox']")
    expect(input["aria-label"]).to include("Utility Name")
  end
end
