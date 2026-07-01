# frozen_string_literal: true

# Reads config/table_layout.yml — column order + category placement (FieldRegistry owns what each
# column is). The table mirror of FilterLayout.
class TableLayout
  # Column keys in table order: pinned first, then each category's columns in definition order.
  def self.column_keys
    @column_keys ||= (pinned_keys + categories.flat_map { |cat| category_columns.fetch(cat.key) }).freeze
  end

  # Ordered CategoryDef records — the column-picker groups, in display order.
  def self.categories
    @categories ||= categories_config.filter_map { |key, body| CategoryDef.new(key: key, label: body.fetch(:label)) if body }.freeze
  end

  # Always-visible columns shown before the category groups (not in the picker).
  def self.pinned_keys
    @pinned_keys ||= Array(config[:pinned]).map(&:to_sym).freeze
  end

  # { column_key => category_key }; pinned/ungrouped columns are absent.
  def self.category_of
    @category_of ||= category_columns.each_with_object({}) do |(cat_key, keys), map|
      keys.each { |key| map[key] = cat_key }
    end.freeze
  end

  def self.reload!
    @config = nil
    @column_keys = nil
    @categories = nil
    @pinned_keys = nil
    @category_columns = nil
    @category_of = nil
    column_keys
  end

  # { category_key => [column keys] } in definition order; tolerates an empty/absent column list.
  def self.category_columns
    @category_columns ||= categories_config.transform_values { |body| Array(body && body[:columns]).map(&:to_sym) }.freeze
  end
  private_class_method :category_columns

  def self.categories_config
    config[:categories] || {}
  end
  private_class_method :categories_config

  def self.config
    @config ||= YAML.safe_load_file(Rails.root.join("config/table_layout.yml"), symbolize_names: true)
  end
  private_class_method :config
end
