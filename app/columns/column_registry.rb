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

  # Pinned columns always included; keys: nil returns all columns.
  def self.visible(keys: nil)
    return columns if keys.nil?
    pinned, selectable = columns.partition(&:pinned)
    pinned + selectable.select { |c| keys.include?(c.key) }
  end

  # Parses the raw cols= query-string value into the canonical key list.
  # Returns nil (all columns), [] (pinned only), or an Array of Symbols.
  def self.parse_keys(raw)
    return nil if raw.nil?
    return [] if raw.strip.empty?
    raw.strip.split(",").map { |k| k.strip.to_sym }
  end

  def self.reload!
    @yaml_config = nil
    @columns = nil
    @categories = nil
    @columns_by_category = nil
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
end
