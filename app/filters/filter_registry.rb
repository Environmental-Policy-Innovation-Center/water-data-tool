# frozen_string_literal: true

# Single source of truth for filter URL keys and range column lists — see config/filters.yml
class FilterRegistry
  def self.config
    @config ||= load_config
  end

  def self.reload!
    @config = nil
    @sortable_columns = nil
    @sortable_table_joins = nil
    @client_payload_json = nil
    config
  end

  # HomeController — flat { "column" => "table_name" } hash derived from sortable_column_groups.
  def self.sortable_columns
    @sortable_columns ||= build_sortable_columns
  end

  # HomeController — { "table_name" => :association } for columns requiring a LEFT JOIN.
  def self.sortable_table_joins
    @sortable_table_joins ||= build_sortable_table_joins
  end

  # Arguments for ActionController::Parameters#permit (symbols + trailing array-shape hash).
  def self.permit_arguments
    [
      *config[:direct_params].map(&:to_sym),
      *config[:special_range_param_keys].map(&:to_sym),
      *area_range_keys,
      *density_range_keys,
      *range_column_permit_keys,
      *violations_range_permit_keys,
      array_params_shape
    ]
  end

  def self.health_subcat_5yr
    config[:violations][:health_subcat_5yr].map(&:to_sym)
  end

  def self.health_subcat_10yr
    config[:violations][:health_subcat_10yr].map(&:to_sym)
  end

  def self.health_subcats_all
    health_subcat_5yr + health_subcat_10yr
  end

  def self.paperwork_violation_columns
    config[:violations][:paperwork].map(&:to_sym)
  end

  def self.demographic_range_columns
    columns_for_group(:demographics)
  end

  def self.environmental_justice_range_columns
    columns_for_group(:environmental_justice)
  end

  def self.funding_range_columns
    columns_for_group(:funding_summary)
  end

  def self.watershed_hazard_range_columns
    columns_for_group(:watershed_hazard)
  end

  def self.trend_range_columns
    columns_for_group(:trend_datum)
  end

  # JSON embedded for the map page — param/column contract for client tooling (see filter_controller.js).
  def self.client_payload
    {
      version: config[:version],
      direct_params: config[:direct_params],
      area_range: config[:area_range],
      density_range: config[:density_range],
      range_column_groups: config[:range_column_groups].transform_values do |group|
        group.slice(:columns, :coercion)
      end,
      violations: config[:violations]
    }
  end

  def self.client_payload_json
    @client_payload_json ||= client_payload.to_json
  end

  def self.load_config
    YAML.safe_load_file(Rails.root.join("config/filters.yml"), symbolize_names: true)
  end
  private_class_method :load_config

  def self.array_params_shape
    config[:array_params]
  end
  private_class_method :array_params_shape

  def self.columns_for_group(key)
    config[:range_column_groups].fetch(key)[:columns].map(&:to_sym)
  end
  private_class_method :columns_for_group

  def self.range_column_permit_keys
    config[:range_column_groups].flat_map do |_, group|
      group[:columns].flat_map { |col| [:"#{col}_min", :"#{col}_max"] }
    end
  end
  private_class_method :range_column_permit_keys

  def self.violations_range_permit_keys
    config[:violations].values.flatten(1).flat_map { |c| [:"#{c}_min", :"#{c}_max"] }
  end
  private_class_method :violations_range_permit_keys

  def self.area_range_keys
    config[:area_range].values_at(:min_key, :max_key).map(&:to_sym)
  end
  private_class_method :area_range_keys

  def self.density_range_keys
    config[:density_range].values_at(:min_key, :max_key).map(&:to_sym)
  end
  private_class_method :density_range_keys

  def self.build_sortable_columns
    config[:sortable_column_groups].each_with_object({}) do |(table, group), hash|
      group[:columns].each { |col| hash[col] = table.to_s }
    end
  end
  private_class_method :build_sortable_columns

  def self.build_sortable_table_joins
    config[:sortable_column_groups].each_with_object({}) do |(table, group), hash|
      next unless group[:association]
      hash[table.to_s] = group[:association].to_sym
    end
  end
  private_class_method :build_sortable_table_joins
end
