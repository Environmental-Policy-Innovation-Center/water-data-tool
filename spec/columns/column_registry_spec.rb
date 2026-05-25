# frozen_string_literal: true

require "rails_helper"

RSpec.describe ColumnRegistry do
  before { ColumnRegistry.reload! }

  it "returns an Array" do
    expect(ColumnRegistry.columns).to be_an(Array)
  end

  it "loads all columns defined in the YAML config" do
    expected = YAML.safe_load_file(Rails.root.join("config/columns.yml"))["columns"].size
    expect(ColumnRegistry.columns.size).to eq(expected)
  end

  it "first column has key: :check" do
    expect(ColumnRegistry.columns.first.key).to eq(:check)
  end

  it "pws_name column has row_header: true" do
    col = ColumnRegistry.columns.find { |c| c.key == :pws_name }
    expect(col.row_header).to be(true)
  end

  it "population_density column has format_opts: { precision: 0 }" do
    col = ColumnRegistry.columns.find { |c| c.key == :population_density }
    expect(col.format_opts).to eq({precision: 0})
  end

  it "reload! clears the memoized value" do
    original = ColumnRegistry.columns
    ColumnRegistry.reload!
    expect(ColumnRegistry.columns).not_to be(original)
  end
end
