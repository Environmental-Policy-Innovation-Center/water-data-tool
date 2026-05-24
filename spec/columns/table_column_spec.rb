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
      sticky: false,
      association: :pws
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
    expect(col.sticky).to be(false)
    expect(col.association).to eq(:pws)
  end

  it "allows nil label (for the checkbox column)" do
    check_col = TableColumn.new(
      key: :check, label: nil, sort: nil, format: :check,
      format_opts: {}, size: :check, sticky: false, association: nil
    )
    expect(check_col.label).to be_nil
  end
end
