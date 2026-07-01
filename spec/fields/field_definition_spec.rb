require "rails_helper"

RSpec.describe FieldDefinition do
  let(:base) do
    described_class.new(key: :poverty_rate, model: :demographic, table: :demographics,
      db_column: nil, source: nil, display: nil, filter: nil, histogram: nil)
  end

  describe "#column" do
    it "is the key when no db_column override is set" do
      expect(base.column).to eq(:poverty_rate)
    end

    it "is the db_column when the key and DB column differ" do
      expect(base.with(key: :epa_report, db_column: :detailed_facility_report).column).to eq(:detailed_facility_report)
    end
  end

  describe "#table_only?" do
    it "is true when the field has no display block (not a table column)" do
      expect(base).to be_table_only
    end

    it "is false when a display block is present" do
      expect(base.with(display: {label: "X"})).not_to be_table_only
    end
  end

  describe "#filter_kind / #cast" do
    it "reads nested keys, symbolizing, and tolerates absent blocks" do
      f = base.with(filter: {kind: "range"}, source: {cast: "decimal"})
      expect(f.filter_kind).to eq(:range)
      expect(f.cast).to eq(:decimal)
      expect(base.filter_kind).to be_nil
      expect(base.cast).to be_nil
    end
  end

  describe "the three range columns" do
    it "distinguishes display value column, filter target column, and URL param base" do
      f = base.with(key: :population_pct_change,
        filter: {column: "population_pct_change_capped", param_base: "population_pct_change_capped"})
      expect(f.column).to eq(:population_pct_change)            # displayed value
      expect(f.filter_column).to eq("population_pct_change_capped") # column the filter targets
      expect(f.filter_param).to eq("population_pct_change_capped")  # URL param base
    end

    it "falls back to the column when the filter declares neither" do
      f = base.with(filter: {kind: "range"})
      expect(f.filter_column).to eq(:poverty_rate)
      expect(f.filter_param).to eq(:poverty_rate)
    end
  end

  describe "#histogram_col" do
    it "uses the histogram column override when present, else the column" do
      expect(base.with(histogram: {column: "capped"}).histogram_col).to eq(:capped)
      expect(base.with(histogram: {format: "percent"}).histogram_col).to eq(:poverty_rate)
    end
  end

  describe "#export_sql" do
    it "qualifies table.column" do
      expect(base.export_sql).to eq("demographics.poverty_rate")
    end

    it "is nil for a value-less field with no table (not exported)" do
      expect(base.with(model: nil, table: nil).export_sql).to be_nil
    end
  end
end
