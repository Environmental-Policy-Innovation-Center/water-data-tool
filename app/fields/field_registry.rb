# frozen_string_literal: true

# Single per-field manifest (config/fields.yml) — see docs/CONFIG_AUDIT.md.
#
# The source of truth for table columns + categories, histogram config, and ETL
# field→model routing. ColumnRegistry (columns) and HistogramsController (histogram config)
# read from here. The remaining filter concerns (permit args, sortable map) still derive from
# config/filters.yml and are cross-checked against this manifest by the parity spec until
# they move over (Phase 5). Tooltips stay in tooltips.yml (CONFIG_AUDIT §8.2).
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

  Field = Data.define(:key, :model, :table, :db_column, :source, :display, :filter, :histogram) do
    def column = db_column || key
    def table_only? = display.nil?
    def category = display && display[:category]&.to_sym
    def cast = source && source[:cast]&.to_sym
    def filter_kind = filter && filter[:kind]&.to_sym

    # A range filter distinguishes three columns the live app conflates: the
    # displayed value column, the column the filter targets, and the URL param base.
    def filter_column = (filter && filter[:column]) || column
    def filter_param = (filter && filter[:param_base]) || filter_column
    def sort_param = display && display[:sort]&.to_s
    def histogram_col = (histogram && histogram[:column]&.to_sym) || column
  end

  def self.fields
    @fields ||= load_fields
  end

  def self.reload!
    @fields = nil
    @config = nil
    @column_records = nil
    @categories = nil
    @table_for = nil
    fields
  end

  # ── ColumnRegistry-equivalent views ─────────────────────────────────────────
  # Array<TableColumn> in manifest order — directly comparable to ColumnRegistry.columns.
  def self.column_records
    @column_records ||= fields.reject(&:table_only?).map { |f| build_table_column(f) }.freeze
  end

  def self.categories
    @categories ||= config.fetch(:categories, []).map { |c| CategoryDef.new(key: c[:key].to_sym, label: c[:label]) }.freeze
  end

  # ── FilterRegistry-equivalent views ────────────────────────────────────────
  def self.range_filter_fields
    fields.select { |f| f.filter_kind == :range }
  end

  # Full ActionController::Parameters#permit arguments — reproduces FilterRegistry.permit_arguments.
  def self.permit_arguments
    scalars = config.fetch(:passthrough_params, []).map(&:to_sym)
    array_shape = {}

    fields.each do |f|
      case f.filter_kind
      when :radio, :bool then scalars << f.filter[:param].to_sym
      when :place then scalars << f.filter[:param].to_sym << f.filter[:name_param].to_sym
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

  # { column_sym => { model: Class, format: "..." } } — consumed by HistogramsController.
  def self.histogram_field_config
    fields.select(&:histogram).each_with_object({}) do |f, config|
      config[f.histogram_col] = {
        model: model_class(f.model),
        format: f.histogram[:format]
      }
    end
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

  def self.build_table_column(f)
    d = f.display
    src = d.key?(:source) ? d[:source]&.to_sym : default_source(f.model)
    TableColumn.new(
      key: f.key,
      label: d[:label],
      sort: d[:sort]&.to_s,
      format: d[:format].to_sym,
      format_opts: (d[:format_opts] || {}).transform_keys(&:to_sym),
      size: d.fetch(:size, "default").to_sym,
      row_header: d[:row_header] || false,
      pinned: d[:pinned] || false,
      source: src,
      category: d[:category]&.to_sym,
      csv_label: d[:csv_label],
      sql_expr: d[:value_sql]
    )
  end
  private_class_method :build_table_column

  # The :pws source marks the base PublicWaterSystem; association name otherwise.
  def self.default_source(model)
    return nil if model.nil?
    (model == :public_water_system) ? :pws : model
  end
  private_class_method :default_source

  # Resolves a manifest `model:` symbol to its ActiveRecord class.
  def self.model_class(model_sym)
    MODEL_CLASSES.fetch(model_sym).constantize
  end
  private_class_method :model_class

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
      Field.new(
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
