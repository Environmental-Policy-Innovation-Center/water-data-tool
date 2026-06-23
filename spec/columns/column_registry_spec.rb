# frozen_string_literal: true

require "rails_helper"

RSpec.describe ColumnRegistry do
  before { ColumnRegistry.reload! }

  it "returns an Array" do
    expect(ColumnRegistry.columns).to be_an(Array)
  end

  it "surfaces every manifest field that has a display block" do
    fields = YAML.safe_load_file(Rails.root.join("config/fields.yml"))["fields"]
    expected = fields.count { |_key, attrs| attrs.key?("display") }
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

  describe ".categories" do
    it "returns an Array of CategoryDef" do
      expect(ColumnRegistry.categories).to be_an(Array)
      expect(ColumnRegistry.categories.first).to be_a(CategoryDef)
    end

    it "includes expected category keys in order" do
      keys = ColumnRegistry.categories.map(&:key)
      expect(keys).to eq([:utility_details, :violations, :demographics, :environmental_justice, :funding, :watershed_hazards])
    end

    it "each category has a label" do
      expect(ColumnRegistry.categories.map(&:label)).to all(be_a(String))
    end
  end

  describe ".columns_by_category" do
    subject(:result) { ColumnRegistry.columns_by_category }

    it "returns a Hash" do
      expect(result).to be_a(Hash)
    end

    it "does not include any pinned columns" do
      pinned_keys = ColumnRegistry.columns.select(&:pinned).map(&:key)
      all_returned_keys = result.values.flatten.map(&:key)
      expect(all_returned_keys).not_to include(*pinned_keys)
    end

    it "groups ungrouped non-pinned columns under the nil key" do
      ungrouped = ColumnRegistry.columns.reject(&:pinned).select { |c| c.category.nil? }
      if ungrouped.any?
        expect(result[nil]).to match_array(ungrouped)
      else
        expect(result.key?(nil)).to be(false)
      end
    end

    it "maps each category key to its expected columns" do
      ColumnRegistry.categories.each do |cat|
        expected = ColumnRegistry.columns.reject(&:pinned).select { |c| c.category == cat.key }
        next if expected.empty?
        expect(result[cat.key]).to match_array(expected)
      end
    end
  end

  describe ".parse_keys" do
    it "returns nil when raw is nil" do
      expect(ColumnRegistry.parse_keys(nil)).to be_nil
    end

    it "returns an empty array when raw is an empty string" do
      expect(ColumnRegistry.parse_keys("")).to eq([])
    end

    it "returns an empty array when raw is whitespace only" do
      expect(ColumnRegistry.parse_keys("   ")).to eq([])
    end

    it "returns an array of symbols for a comma-separated string" do
      expect(ColumnRegistry.parse_keys("pwsid,stusps,counties")).to eq([:pwsid, :stusps, :counties])
    end

    it "strips leading/trailing whitespace from the raw value" do
      expect(ColumnRegistry.parse_keys("  pwsid,stusps  ")).to eq([:pwsid, :stusps])
    end

    it "returns a single-element array for a single key" do
      expect(ColumnRegistry.parse_keys("pwsid")).to eq([:pwsid])
    end
  end

  describe ".visible" do
    it "returns all columns when keys is nil" do
      expect(ColumnRegistry.visible(keys: nil)).to eq(ColumnRegistry.columns)
    end

    it "always includes pinned columns regardless of keys" do
      pinned_keys = ColumnRegistry.columns.select(&:pinned).map(&:key)
      result = ColumnRegistry.visible(keys: [])
      expect(result.map(&:key)).to include(*pinned_keys)
    end

    it "excludes non-pinned columns not in the keys set" do
      result = ColumnRegistry.visible(keys: [:pwsid])
      non_pinned_keys = result.reject(&:pinned).map(&:key)
      expect(non_pinned_keys).not_to include(:stusps, :counties)
    end

    it "includes non-pinned columns whose key is in the keys set" do
      result = ColumnRegistry.visible(keys: [:pwsid, :stusps])
      non_pinned_keys = result.reject(&:pinned).map(&:key)
      expect(non_pinned_keys).to include(:pwsid, :stusps)
    end

    it "returns non-pinned columns in the order specified by keys" do
      result = ColumnRegistry.visible(keys: [:counties, :stusps, :pwsid])
      non_pinned_keys = result.reject(&:pinned).map(&:key)
      expect(non_pinned_keys).to eq([:counties, :stusps, :pwsid])
    end

    it "places pinned columns before reordered selectable columns" do
      result = ColumnRegistry.visible(keys: [:stusps, :pwsid])
      expect(result.map(&:key).first(2)).to eq([:check, :pws_name])
    end
  end

  describe ".parse_column_state" do
    it "returns nil panel_col_keys and nil visible_col_keys when raw is nil" do
      state = ColumnRegistry.parse_column_state(nil)
      expect(state.panel_col_keys).to be_nil
      expect(state.visible_col_keys).to be_nil
    end

    it "returns empty arrays when raw is blank" do
      state = ColumnRegistry.parse_column_state("")
      expect(state.panel_col_keys).to eq([])
      expect(state.visible_col_keys).to eq([])
    end

    it "parses visible col keys from a new-format string with - prefix" do
      state = ColumnRegistry.parse_column_state("counties,-pwsid,stusps")
      expect(state.visible_col_keys).to eq([:counties, :stusps])
    end

    it "preserves full panel order including hidden positions from - prefix string" do
      state = ColumnRegistry.parse_column_state("counties,-pwsid,stusps")
      expect(state.panel_col_keys).to eq(["counties", "-pwsid", "stusps"])
    end

    it "handles legacy string with no - prefix: visible_col_keys contains only those keys" do
      state = ColumnRegistry.parse_column_state("counties,stusps")
      expect(state.visible_col_keys).to eq([:counties, :stusps])
    end

    it "appends remaining selectable cols as hidden in legacy format" do
      state = ColumnRegistry.parse_column_state("counties,stusps")
      expect(state.panel_col_keys).to start_with(["counties", "stusps"])
      hidden_tail = state.panel_col_keys.drop(2)
      expect(hidden_tail).to all(start_with("-"))
      expect(hidden_tail).not_to include("-counties", "-stusps")
    end
  end

  describe ".panel_groups" do
    it "returns YAML-ordered groups when col_keys is nil" do
      groups = ColumnRegistry.panel_groups(col_keys: nil)
      expect(groups).not_to be_empty
      expect(groups.first[:type]).to be_in([:column, :category])
      utility = groups.find { |g| g[:type] == :category && g[:cat].key == :utility_details }
      expect(utility[:cols].map(&:key)).to eq(ColumnRegistry.columns_by_category[:utility_details].map(&:key))
    end

    it "returns empty array when col_keys is empty" do
      expect(ColumnRegistry.panel_groups(col_keys: [])).to eq([])
    end

    it "orders columns within a category by col_keys order" do
      groups = ColumnRegistry.panel_groups(col_keys: ["counties", "stusps"])
      utility = groups.find { |g| g[:type] == :category && g[:cat].key == :utility_details }
      expect(utility[:cols].map(&:key)).to eq([:counties, :stusps])
    end

    it "includes hidden columns (- prefix) in panel order" do
      groups = ColumnRegistry.panel_groups(col_keys: ["counties", "-pwsid", "stusps"])
      utility = groups.find { |g| g[:type] == :category && g[:cat].key == :utility_details }
      expect(utility[:cols].map(&:key)).to eq([:counties, :pwsid, :stusps])
    end

    it "splits category blocks when col_keys interleave different categories" do
      health_key = ColumnRegistry.columns.find { |c| c.category == :violations }&.key
      expect(health_key).not_to be_nil, "expected the manifest to have at least one :violations column"
      groups = ColumnRegistry.panel_groups(col_keys: ["stusps", health_key.to_s, "pwsid"])
      category_groups = groups.select { |g| g[:type] == :category }
      expect(category_groups.size).to be >= 2
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

    it "limits columns to pinned + specified keys when keys: is an Array" do
      result = ColumnRegistry.csv_columns(keys: [:stusps])
      expect(result.keys).to include("Utility Name")
      expect(result.keys).to include("State")
      expect(result.keys).not_to include("Has open violations")
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
