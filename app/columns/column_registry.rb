# frozen_string_literal: true

class ColumnRegistry
  def self.columns
    @columns ||= load_columns
  end

  def self.categories
    @categories ||= load_categories
  end

  def self.columns_by_category
    @columns_by_category ||= columns.reject(&:pinned).group_by(&:category).freeze
  end

  ColumnState = Data.define(:panel_col_keys, :visible_col_keys)

  # panel_col_keys:   nil = YAML default; Array<String> of raw keys, "-key" = hidden
  # visible_col_keys: nil = all visible; Array<Symbol> of checked column keys only
  def self.parse_column_state(raw)
    return ColumnState.new(panel_col_keys: nil, visible_col_keys: nil) if raw.nil?
    return ColumnState.new(panel_col_keys: [], visible_col_keys: []) if raw.strip.empty?

    raw_keys = raw.strip.split(",").map(&:strip).reject(&:empty?)
    hidden_raw, visible_raw = raw_keys.partition { |k| k.start_with?("-") }
    visible_col_keys = visible_raw.map(&:to_sym)

    if hidden_raw.any?
      ColumnState.new(panel_col_keys: raw_keys, visible_col_keys:)
    else
      # Legacy format: visible keys only — append remaining selectable cols as hidden
      selectable_keys = columns.reject(&:pinned).map { |c| c.key.to_s }
      hidden_tail = (selectable_keys - visible_raw).map { |k| "-#{k}" }
      ColumnState.new(panel_col_keys: visible_raw + hidden_tail, visible_col_keys:)
    end
  end

  # col_keys: nil → YAML default (all columns, definition order).
  # col_keys: [] → empty panel (pinned-only scenario).
  # col_keys: Array<String> → panel follows that order; "-key" entries are included as hidden.
  def self.panel_groups(col_keys: nil)
    return yaml_panel_groups if col_keys.nil?
    return [] if col_keys.empty?

    selectable_by_key = columns.reject(&:pinned).index_by { |c| c.key.to_s }
    ordered_cols = col_keys.filter_map { |k| selectable_by_key[k.delete_prefix("-")] }
    build_groups(ordered_cols).freeze
  end

  # Pinned columns always included; keys: nil returns all columns in YAML order.
  def self.visible(keys: nil)
    return columns if keys.nil?
    pinned, selectable = columns.partition(&:pinned)
    selectable_by_key = selectable.index_by(&:key)
    pinned + keys.filter_map { |k| selectable_by_key[k] }
  end

  # Returns visible col keys only — use parse_column_state for full panel state.
  def self.parse_keys(raw)
    parse_column_state(raw).visible_col_keys
  end

  def self.reload!
    @yaml_config = nil
    @columns = nil
    @categories = nil
    @columns_by_category = nil
    @categories_by_key = nil
    @yaml_panel_groups = nil
    columns
    categories
  end

  # Returns { csv_label => sql_expr } for exported columns.
  # Pass keys: to restrict to a visible column set (nil = all columns).
  # Bool-format columns have ::text appended so PG emits "true"/"false" rather than "t"/"f".
  def self.csv_columns(keys: nil)
    visible(keys: keys).each_with_object({}) do |col, h|
      next if col.sql_expr.nil?
      expr = (col.format == :bool) ? "#{col.sql_expr}::text" : col.sql_expr
      h[col.csv_label] = expr
    end
  end

  # Returns { key.to_s => sql_expr } for all exported columns.
  # Boolean columns use native PG booleans (no ::text cast).
  def self.geojson_columns
    columns.each_with_object({}) do |col, h|
      next if col.sql_expr.nil?
      h[col.key.to_s] = col.sql_expr
    end
  end

  def self.yaml_config
    @yaml_config ||= YAML.safe_load_file(Rails.root.join("config/columns.yml"), symbolize_names: true)
  end
  private_class_method :yaml_config

  def self.load_categories
    (yaml_config[:categories] || []).map { |c| CategoryDef.new(key: c[:key].to_sym, label: c[:label]) }.freeze
  end
  private_class_method :load_categories

  def self.load_columns
    yaml_config[:columns].map do |attrs|
      TableColumn.new(
        key: attrs[:key].to_sym,
        label: attrs[:label],
        sort: attrs[:sort]&.to_s,
        format: attrs[:format].to_sym,
        format_opts: (attrs[:format_opts] || {}).transform_keys(&:to_sym),
        size: attrs[:size].to_sym,
        row_header: attrs[:row_header] || false,
        pinned: attrs[:pinned] || false,
        source: attrs[:source]&.to_sym,
        csv_label: attrs[:csv_label],
        sql_expr: attrs[:sql_expr],
        category: attrs[:category]&.to_sym
      )
    end.freeze
  end
  private_class_method :load_columns

  def self.yaml_panel_groups
    @yaml_panel_groups ||= begin
      ordered = (columns_by_category[nil] || []) +
        categories.flat_map { |cat| columns_by_category[cat.key] || [] }
      build_groups(ordered).freeze
    end
  end
  private_class_method :yaml_panel_groups

  def self.categories_by_key
    @categories_by_key ||= categories.index_by(&:key)
  end
  private_class_method :categories_by_key

  def self.build_groups(ordered_cols)
    groups = []
    ordered_cols.each do |col|
      if col.category.nil?
        groups << {type: :column, col: col}
      else
        last = groups.last
        if last&.dig(:type) == :category && last[:cat].key == col.category
          last[:cols] << col
        else
          groups << {type: :category, cat: categories_by_key[col.category], cols: [col]}
        end
      end
    end
    groups
  end
  private_class_method :build_groups
end
