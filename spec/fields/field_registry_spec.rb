# frozen_string_literal: true

require "rails_helper"

# Backstop for the config consolidation — see docs/CONFIG_AUDIT.md.
#
# Table columns are consumed from the manifest by ColumnRegistry (guarded by
# column_registry_spec); histogram config is owned and tested here. The parity block stays
# meaningful only for the concerns not yet cut over — permit args + sortable map still derive
# from config/filters.yml, so it cross-checks the manifest against drift until Phase 5. The
# invariants are the durable safety net that survives consolidation.
RSpec.describe FieldRegistry do
  before do
    FieldRegistry.reload!
    ColumnRegistry.reload!
    FilterRegistry.reload!
  end

  describe "parity with FilterRegistry (filters.yml — not yet cut over)" do
    it "permits exactly the same scalar param keys" do
      expect(scalar_permit_keys(FieldRegistry.permit_arguments))
        .to eq(scalar_permit_keys(FilterRegistry.permit_arguments))
    end

    it "permits exactly the same array-shaped params" do
      expect(array_permit_shape(FieldRegistry.permit_arguments))
        .to eq(array_permit_shape(FilterRegistry.permit_arguments))
    end

    it "reproduces the sortable column → table map" do
      expect(FieldRegistry.sortable_columns).to eq(FilterRegistry.sortable_columns)
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

  def scalar_permit_keys(args)
    args.reject { |a| a.is_a?(Hash) }.map(&:to_sym).to_set
  end

  def array_permit_shape(args)
    args.find { |a| a.is_a?(Hash) }
  end
end
