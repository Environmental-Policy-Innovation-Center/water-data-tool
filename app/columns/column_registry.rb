# frozen_string_literal: true

class ColumnRegistry
  def self.columns
    @columns ||= load_columns
  end

  def self.reload!
    @columns = nil
    columns
  end

  def self.load_columns
    config = YAML.safe_load_file(Rails.root.join("config/columns.yml"), symbolize_names: true)
    config[:columns].map do |attrs|
      TableColumn.new(
        key: attrs[:key].to_sym,
        label: attrs[:label],
        sort: attrs[:sort]&.to_s,
        format: attrs[:format].to_sym,
        format_opts: (attrs[:format_opts] || {}).transform_keys(&:to_sym),
        size: attrs[:size].to_sym,
        sticky: attrs[:sticky],
        association: attrs[:association]&.to_sym
      )
    end.freeze
  end
  private_class_method :load_columns
end
