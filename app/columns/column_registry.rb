# frozen_string_literal: true

# Table-column behavior — panel groups, visibility, CSV/GeoJSON export. The column
# definitions come from the manifest via FieldRegistry (config/fields.yml).
class ColumnRegistry
  def self.columns
    @columns ||= FieldRegistry.column_records
  end

  def self.categories
    @categories ||= FieldRegistry.categories
  end

  def self.columns_by_category
    @columns_by_category ||= columns.reject(&:pinned).group_by(&:category).freeze
  end

  ColumnState = Data.define(:panel_col_keys, :visible_col_keys)

  # panel_col_keys:   nil = manifest default; Array<String> of raw keys, "-key" = hidden
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

  # col_keys: nil → manifest default (all columns, definition order).
  # col_keys: [] → empty panel (pinned-only scenario).
  # col_keys: Array<String> → panel follows that order; "-key" entries are included as hidden.
  def self.panel_groups(col_keys: nil)
    return default_panel_groups if col_keys.nil?
    return [] if col_keys.empty?

    selectable_by_key = columns.reject(&:pinned).index_by { |c| c.key.to_s }
    ordered_cols = col_keys.filter_map { |k| selectable_by_key[k.delete_prefix("-")] }
    build_groups(ordered_cols).freeze
  end

  # Pinned columns always included; keys: nil returns all columns in manifest order.
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
    FieldRegistry.reload!
    @columns = nil
    @categories = nil
    @columns_by_category = nil
    @categories_by_key = nil
    @default_panel_groups = nil
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

  # Default panel order: ungrouped columns first, then each category's columns in manifest order.
  def self.default_panel_groups
    @default_panel_groups ||= begin
      ungrouped = columns_by_category[nil] || []
      grouped = categories.flat_map { |cat| columns_by_category[cat.key] || [] }
      build_groups(ungrouped + grouped).freeze
    end
  end
  private_class_method :default_panel_groups

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
