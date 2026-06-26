# frozen_string_literal: true

# Reads config/filter_layout.yml — where each filter is placed (FieldRegistry owns what each filter is).
class FilterLayout
  # A leaf filter's placement: menu → category → filter; parent = the key it nests under, or nil.
  Placement = Data.define(:key, :menu, :category, :parent)

  def self.menus
    @menus ||= config.fetch(:menus)
  end

  def self.reload!
    @config = nil
    @menus = nil
    @placements = nil
    placements
  end

  # Every leaf field placement, in layout order (filters with sub-filters are flattened
  # to their sub-filters).
  def self.placements
    @placements ||= menus.flat_map do |menu_key, menu|
      menu.fetch(:categories).flat_map do |category_key, category|
        category.fetch(:filters).flat_map { |filter| placements_for(filter, menu_key, category_key) }
      end
    end.freeze
  end

  # The field keys referenced by the layout, in order.
  def self.field_keys
    placements.map(&:key)
  end

  # A filter is either a field key (String) or a parent-filter Hash { key => {sub_filters: [...]} }.
  def self.placements_for(filter, menu_key, category_key)
    case filter
    when String
      [Placement.new(key: filter.to_sym, menu: menu_key, category: category_key, parent: nil)]
    when Hash
      filter.flat_map do |filter_key, body|
        body.fetch(:sub_filters).map { |key| Placement.new(key: key.to_sym, menu: menu_key, category: category_key, parent: filter_key) }
      end
    else
      raise "unexpected filter_layout filter: #{filter.inspect}"
    end
  end
  private_class_method :placements_for

  def self.config
    @config ||= YAML.safe_load_file(Rails.root.join("config/filter_layout.yml"), symbolize_names: true)
  end
  private_class_method :config
end
