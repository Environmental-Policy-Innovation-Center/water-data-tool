require "rails_helper"

RSpec.describe TableColumn do
  let(:col) do
    TableColumn.new(
      key: :pwsid,
      label: "Utility ID",
      sort: "pwsid",
      format: :str,
      format_opts: {},
      size: :default,
      row_header: false,
      pinned: false,
      read_from: :pws,
      csv_label: "Utility ID",
      sql_expr: "pws.pwsid",
      category: nil
    )
  end

  it "instantiates with keyword_init" do
    expect(col).to be_a(TableColumn)
  end

  it "exposes all expected attributes" do
    expect(col.key).to eq(:pwsid)
    expect(col.label).to eq("Utility ID")
    expect(col.sort).to eq("pwsid")
    expect(col.format).to eq(:str)
    expect(col.format_opts).to eq({})
    expect(col.size).to eq(:default)
    expect(col.row_header).to be(false)
    expect(col.pinned).to be(false)
    expect(col.read_from).to eq(:pws)
  end

  it "exposes export fields" do
    expect(col.csv_label).to eq("Utility ID")
    expect(col.sql_expr).to eq("pws.pwsid")
  end

  it "allows nil csv_label and sql_expr (for non-exported columns)" do
    check_col = TableColumn.new(
      key: :check, label: nil, sort: nil, format: :check,
      format_opts: {}, size: :check, row_header: false, pinned: true, read_from: nil,
      csv_label: nil, sql_expr: nil, category: nil
    )
    expect(check_col.label).to be_nil
    expect(check_col.csv_label).to be_nil
    expect(check_col.sql_expr).to be_nil
  end
end
