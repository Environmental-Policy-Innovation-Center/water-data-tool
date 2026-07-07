module Sortable
  extend ActiveSupport::Concern

  SORTABLE_COLUMNS = FieldRegistry.sortable_columns.freeze
  TABLE_JOINS = FieldRegistry.sortable_table_joins.freeze
  DEFAULT_SORT_COLUMN = "pws_name"

  def apply_search(scope, term)
    sanitized = term.gsub(/[%_\\]/) { |c| "\\#{c}" }
    scope.where(
      "public_water_systems.pws_name ILIKE :q OR public_water_systems.pwsid ILIKE :q " \
      "OR public_water_systems.stusps ILIKE :q OR public_water_systems.counties ILIKE :q",
      q: "%#{sanitized}%"
    )
  end

  def apply_sort_join(scope)
    # public_water_systems columns return nil here — they're on the primary model so no join is needed.
    assoc = TABLE_JOINS[SORTABLE_COLUMNS[resolved_sort_col]]
    assoc ? scope.left_joins(assoc) : scope
  end

  def order_clause
    sort_col = resolved_sort_col
    sort_table = SORTABLE_COLUMNS[sort_col]
    col_node = Arel::Table.new(sort_table)[sort_col]
    order_node = (params[:direction] == "desc") ? col_node.desc.nulls_last : col_node.asc.nulls_last
    return order_node if sort_col == DEFAULT_SORT_COLUMN
    [order_node, Arel::Table.new("public_water_systems")[DEFAULT_SORT_COLUMN].asc]
  end

  def resolved_sort_col
    @resolved_sort_col ||= SORTABLE_COLUMNS.key?(params[:sort]) ? params[:sort] : DEFAULT_SORT_COLUMN
  end
end
