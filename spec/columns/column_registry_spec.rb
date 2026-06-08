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

  describe ".visible" do
    it "returns all columns when keys is nil" do
      expect(ColumnRegistry.visible(keys: nil)).to eq(ColumnRegistry.columns)
    end

    it "always includes pinned columns regardless of keys" do
      pinned_keys = ColumnRegistry.columns.select(&:pinned).map(&:key)
      result = ColumnRegistry.visible(keys: Set.new)
      expect(result.map(&:key)).to include(*pinned_keys)
    end

    it "excludes non-pinned columns not in the keys set" do
      result = ColumnRegistry.visible(keys: Set[:pwsid])
      non_pinned_keys = result.reject(&:pinned).map(&:key)
      expect(non_pinned_keys).not_to include(:stusps, :counties)
    end

    it "includes non-pinned columns whose key is in the keys set" do
      result = ColumnRegistry.visible(keys: Set[:pwsid, :stusps])
      non_pinned_keys = result.reject(&:pinned).map(&:key)
      expect(non_pinned_keys).to include(:pwsid, :stusps)
    end
  end

  describe ".csv_columns" do
    subject(:result) { ColumnRegistry.csv_columns }

    it "returns a Hash" do
      expect(result).to be_a(Hash)
    end

    it "uses csv_label as key" do
      expect(result.keys).to include("Utility Name", "Utility ID", "State")
    end

    it "uses sql_expr as value for non-boolean columns" do
      expect(result["Utility Name"]).to eq("pws.pws_name")
    end

    it "appends ::text to sql_expr for bool-format columns" do
      expect(result["Wholesaler"]).to eq("pws.is_wholesaler::text")
      expect(result["Grant eligible"]).to eq("pws.is_grant_eligible::text")
    end

    it "excludes columns without sql_expr" do
      expect(result.keys).not_to include(nil)
      expect(result.size).to be < ColumnRegistry.columns.size
    end
  end

  describe ".geojson_columns" do
    subject(:result) { ColumnRegistry.geojson_columns }

    it "returns a Hash" do
      expect(result).to be_a(Hash)
    end

    it "uses key.to_s as property name" do
      expect(result.keys).to include("pwsid", "pws_name", "stusps")
    end

    it "uses sql_expr as value without ::text for boolean columns" do
      expect(result["is_wholesaler"]).to eq("pws.is_wholesaler")
      expect(result["source_water_protection_code"]).to eq("pws.source_water_protection_code")
    end

    it "excludes columns without sql_expr" do
      expect(result.keys).not_to include("check")
      expect(result.size).to be < ColumnRegistry.columns.size
    end

    it "includes is_grant_eligible" do
      expect(result.keys).to include("is_grant_eligible")
    end
  end
end
