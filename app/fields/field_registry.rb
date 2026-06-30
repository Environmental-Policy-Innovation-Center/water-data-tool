# frozen_string_literal: true

# Single per-field manifest (config/fields.yml) — see docs/CONFIG_AUDIT.md.
#
# The source of truth for table columns + categories, filter permit args + sortable maps,
# histogram config, and ETL field→model routing. ColumnRegistry, Filterable, Sortable,
# FilterParams, and HistogramsController all read from here; tooltips stay in tooltips.yml
# (CONFIG_AUDIT §8.2).
class FieldRegistry
  # Manifest `model:` symbol → ActiveRecord class name (resolved lazily for histogram
  # config + invariant checks).
  MODEL_CLASSES = {
    public_water_system: "PublicWaterSystem",
    violations_summary: "ViolationsSummary",
    boil_water_summary: "BoilWaterSummary",
    demographic: "Demographic",
    trend_datum: "TrendDatum",
    environmental_justice: "EnvironmentalJustice",
    funding_summary: "FundingSummary",
    watershed_hazard: "WatershedHazard"
  }.freeze

  def self.fields
    @fields ||= load_fields
  end

  # Field by manifest key — the generator resolves layout references through this.
  def self.find(key)
    by_key.fetch(key.to_sym)
  end

  def self.by_key
    @by_key ||= fields.index_by(&:key).freeze
  end

  def self.reload!
    @fields = nil
    @config = nil
    @by_key = nil
    @display_field_keys = nil
    @table_for = nil
    fields
  end

  # Field keys with a table display block — the manifest's displayable columns. ColumnRegistry
  # composes these with TableLayout into the rendered TableColumns.
  def self.display_field_keys
    @display_field_keys ||= fields.reject(&:table_only?).map(&:key).freeze
  end

  # ── Filter permit args + sortable maps ──────────────────────────────────────
  def self.range_filter_fields
    fields.select { |f| f.filter_kind == :range }
  end

  # Full ActionController::Parameters#permit arguments for every filter param — derived from
  # each field's filter.kind, so a new filter is permitted just by adding it to the manifest:
  #   radio / bool → param   |   range → param_min + param_max   |   multiselect → param: []
  # Plus passthrough_params (params with no owning field, e.g. map viewport / geographic scope).
  def self.permit_arguments
    scalars = config.fetch(:passthrough_params, []).map(&:to_sym)
    array_shape = {}

    fields.each do |f|
      case f.filter_kind
      when :radio, :bool then scalars << f.filter[:param].to_sym
      when :range then scalars << :"#{f.filter_param}_min" << :"#{f.filter_param}_max"
      when :multiselect then array_shape[f.filter[:param].to_sym] = []
      end
    end

    [*scalars, array_shape]
  end

  # { sort_param_string => table_string } for every sortable column.
  def self.sortable_columns
    fields.select(&:sort_param).to_h { |f| [f.sort_param, f.table.to_s] }
  end

  # { table_string => association_sym } — the LEFT JOIN each sortable association needs (the
  # association is the model symbol). Base-model columns need no join, so they're skipped.
  def self.sortable_table_joins
    fields.select(&:sort_param)
      .reject { |f| f.model == :public_water_system }
      .to_h { |f| [f.table.to_s, f.model] }
  end

  # Resolves a manifest `model:` symbol to its ActiveRecord class.
  def self.model_class(model_sym)
    MODEL_CLASSES.fetch(model_sym).constantize
  end

  # { column_sym => { model: Class, format: "..." } } — consumed by HistogramsController.
  def self.histogram_field_config
    fields.select(&:histogram).each_with_object({}) do |f, config|
      config[f.histogram_col] = {
        model: model_class(f.model),
        format: f.histogram[:format]
      }
    end
  end

  # { file_sym => { model:, reason: } } — source files that keep a custom importer
  # because their ingestion isn't a flat column→header→cast map (see CONFIG_AUDIT §8.1).
  def self.custom_imports
    config.fetch(:custom_imports, {})
  end

  # ── ETL field→model routing derived from the manifest ───────────────────────
  def self.etl_mapping
    fields.each_with_object({}) do |f, by_file|
      next unless f.source

      by_model = (by_file[f.source[:file].to_sym] ||= {})
      by_model[f.model] ||= []
      by_model[f.model] << {db_column: f.column, header: f.source[:header], cast: f.cast}
    end
  end

  def self.config
    @config ||= YAML.safe_load_file(Rails.root.join("config/fields.yml"), symbolize_names: true)
  end
  private_class_method :config

  # SQL table name is a deterministic function of the model (Model.table_name) —
  # never independent — so it is derived, not stored in the manifest. Verified equal
  # for all models including the irregular trend_datum → trend_data.
  def self.table_for(model_sym)
    return nil if model_sym.nil?
    (@table_for ||= {})[model_sym] ||= model_class(model_sym).table_name.to_sym
  end
  private_class_method :table_for

  def self.load_fields
    config.fetch(:fields).map do |key, attrs|
      model_sym = attrs[:model]&.to_sym
      FieldDefinition.new(
        key: key,
        model: model_sym,
        table: table_for(model_sym),
        db_column: attrs[:db_column]&.to_sym,
        source: attrs[:source],
        display: attrs[:display],
        filter: attrs[:filter],
        histogram: attrs[:histogram]
      )
    end.freeze
  end
  private_class_method :load_fields
end
