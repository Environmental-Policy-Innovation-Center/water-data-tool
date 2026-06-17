require "rails_helper"

RSpec.describe ManageColumns::ColumnRowComponent, type: :component do
  let(:ungrouped_col) do
    TableColumn.new(
      key: :pwsid, label: "Utility ID", sort: "pwsid", format: :str,
      format_opts: {}, size: :default, row_header: false, pinned: false,
      source: :pws, csv_label: "Utility ID", sql_expr: "pws.pwsid", category: nil
    )
  end

  let(:grouped_col) do
    TableColumn.new(
      key: :health_violations_5yr, label: "Health violations (5yr)", sort: "health_violations_5yr",
      format: :num, format_opts: {}, size: :default, row_header: false, pinned: false,
      source: :violations_summary, csv_label: "Health violations in the last 5 years",
      sql_expr: "vs.health_violations_5yr", category: :violations
    )
  end

  context "ungrouped column" do
    before { render_inline(described_class.new(col: ungrouped_col, checked: true)) }

    it "renders an li with drag handle and label" do
      expect(html.at_css("li")).to be_present
      expect(html.text).to include("Utility ID")
      expect(html.at_css("button.drag-handle")).to be_present
    end

    it "renders a checked checkbox with data-col-key" do
      input = html.at_css("input[type='checkbox']")
      expect(input["data-col-key"]).to eq("pwsid")
      expect(input["checked"]).to be_present
    end

    it "has no data-category or syncCategoryState action" do
      input = html.at_css("input[type='checkbox']")
      expect(input["data-category"]).to be_nil
      expect(input["data-action"]).to be_nil
    end

    it "uses standard (non-indented) padding" do
      expect(html.at_css("li")["class"]).to include("px-2")
    end
  end

  context "grouped column (indented)" do
    before { render_inline(described_class.new(col: grouped_col, checked: false, indented: true)) }

    it "renders an unchecked checkbox" do
      expect(html.at_css("input[type='checkbox']")["checked"]).to be_nil
    end

    it "includes data-category and syncCategoryState action" do
      input = html.at_css("input[type='checkbox']")
      expect(input["data-category"]).to eq("violations")
      expect(input["data-action"]).to eq("change->manage-columns#syncCategoryState")
    end

    it "uses indented padding" do
      expect(html.at_css("li")["class"]).to include("pl-6")
    end
  end
end
