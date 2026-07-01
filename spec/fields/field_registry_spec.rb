# frozen_string_literal: true

require "rails_helper"

# Backstop for the config consolidation — see docs/CONFIG_AUDIT.md. The manifest is the sole source
# for table columns (guarded by column_registry_spec), filter permit args + sortable maps, histogram
# config, and ETL field→model routing. These specs pin the manifest-derived outputs directly; the
# invariants below are the durable safety net.
RSpec.describe FieldRegistry do
  before do
    FieldRegistry.reload!
    ColumnRegistry.reload!
  end

  describe ".permit_arguments" do
    it "includes the capped trend range keys, not the raw uncapped param" do
      flat = permit_flat_keys(FieldRegistry.permit_arguments)
      expect(flat).to include(:population_pct_change_capped_min, :population_pct_change_capped_max)
      expect(flat).to include(:mhi_pct_change_capped_min, :mhi_pct_change_capped_max)
      expect(flat).not_to include(:population_pct_change_min)
    end

    it "shapes the multiselect params as a trailing array-permit hash" do
      args = FieldRegistry.permit_arguments
      expect(args.last).to be_a(Hash)
      expect(args.last.keys).to include(:owner_type, :primacy_type, :pop_cat_5, :most_common_rate_tier)
    end

    it "includes violation range min/max keys" do
      flat = permit_flat_keys(FieldRegistry.permit_arguments)
      expect(flat).to include(:groundwater_rule_5yr_min, :lead_and_copper_10yr_max)
    end
  end

  describe ".sortable_columns / .sortable_table_joins" do
    it "maps each sortable column to its table" do
      expect(FieldRegistry.sortable_columns)
        .to include("pws_name" => "public_water_systems", "total_notices" => "boil_water_summaries")
    end

    it "joins only the non-base sortable tables (association = model symbol)" do
      joins = FieldRegistry.sortable_table_joins
      expect(joins).to include("boil_water_summaries" => :boil_water_summary, "demographics" => :demographic)
      expect(joins).not_to have_key("public_water_systems")
    end
  end

  describe ".histogram_field_config (sole source — consumed by HistogramsController)" do
    it "maps each histogram column to its model and display format" do
      cfg = FieldRegistry.histogram_field_config
      expect(cfg[:poverty_rate]).to eq({model: Demographic, format: "percent"})
      expect(cfg[:median_household_income]).to eq({model: Demographic, format: "currency"})
      expect(cfg[:population_pct_change_capped]).to eq({model: TrendDatum, format: "percent_change"})
      expect(cfg[:paperwork_violations_5yr]).to eq({model: ViolationsSummary, format: "count"})
    end
  end

  describe "durable invariants (the safety net)" do
    it "every data field's column actually exists on its model's table" do
      FieldRegistry.fields.select(&:model).each do |f|
        klass = described_class::MODEL_CLASSES.fetch(f.model).constantize
        expect(klass.column_names).to include(f.column.to_s),
          "field #{f.key} → #{f.model}.#{f.column} is not a real column"
      end
    end

    it "every range filter targets a real DB column" do
      FieldRegistry.range_filter_fields.each do |f|
        klass = described_class::MODEL_CLASSES.fetch(f.model).constantize
        expect(klass.column_names).to include(f.filter_column.to_s),
          "range filter #{f.key} targets missing column #{f.filter_column}"
      end
    end

    it "every histogram column resolves on its model" do
      FieldRegistry.fields.select(&:histogram).each do |f|
        klass = described_class::MODEL_CLASSES.fetch(f.model).constantize
        expect(klass.column_names).to include(f.histogram_col.to_s)
      end
    end
  end

  describe "model routing is independent of UI category" do
    it "places trend_datum-backed fields under the Demographics table category" do
      f = FieldRegistry.fields.find { |x| x.key == :population_pct_change }
      expect(f.model).to eq(:trend_datum)
      expect(TableLayout.category_of[:population_pct_change]).to eq(:demographics)
    end
  end

  describe ".etl_mapping (field → model routing, derived from the manifest)" do
    subject(:mapping) { FieldRegistry.etl_mapping }

    it "routes each known source file to its destination model" do
      expect(mapping[:epa_sabs_xwalk].keys).to contain_exactly(:demographic)
      expect(mapping[:xwalk_pct_change_10yr].keys).to contain_exactly(:trend_datum)
    end

    it "carries the raw header + cast a generic importer needs" do
      poverty = mapping[:epa_sabs_xwalk][:demographic].find { |c| c[:db_column] == :poverty_rate }
      expect(poverty).to eq(db_column: :poverty_rate, header: "hh_below_pov_per", cast: :decimal)
    end
  end

  def permit_flat_keys(args)
    args.flat_map { |x| x.is_a?(Hash) ? x.keys : x }
  end
end
