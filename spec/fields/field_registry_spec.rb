# frozen_string_literal: true

require "rails_helper"

# Phase 0 + Phase 2 of docs/CONFIG_AUDIT.md.
#
# The PARITY block is the cutover backstop: it asserts FieldRegistry reproduces the
# legacy ColumnRegistry + FilterRegistry output field-for-field, so Phase 3 can point
# the live consumers at the manifest with confidence. The INVARIANTS block is the
# durable safety net that survives consolidation.
RSpec.describe FieldRegistry do
  before do
    FieldRegistry.reload!
    ColumnRegistry.reload!
    FilterRegistry.reload!
  end

  describe "parity with ColumnRegistry (table columns)" do
    it "reproduces every column, in order, identically" do
      expect(FieldRegistry.column_records).to eq(ColumnRegistry.columns)
    end

    it "reproduces the category list, in order" do
      expect(FieldRegistry.categories).to eq(ColumnRegistry.categories)
    end
  end

  describe "parity with FilterRegistry (filters)" do
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

    it "reproduces the histogram field config" do
      expect(FieldRegistry.histogram_field_config).to eq(FilterRegistry.histogram_field_config)
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
    it "places trend_datum-backed fields under the Demographics category" do
      f = FieldRegistry.fields.find { |x| x.key == :population_pct_change }
      expect(f.model).to eq(:trend_datum)
      expect(f.category).to eq(:demographics)
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
