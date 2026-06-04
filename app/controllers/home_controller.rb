class HomeController < ApplicationController
  SORTABLE_COLUMNS = FilterRegistry.sortable_columns.freeze
  TABLE_JOINS = FilterRegistry.sortable_table_joins.freeze
  DEFAULT_SORT_COLUMN = "pws_name"

  def index
    @last_updated = DataImport.maximum(:imported_at)
    @visible_col_keys = params[:cols].blank? ? nil : params[:cols].split(",").map(&:to_sym).to_set
  end

  def map
    scope = PublicWaterSystem.apply_filters(filter_params)
    render json: {pwsids: scope.pluck(:pwsid)}
  end

  def table
    scope = PublicWaterSystem.apply_filters(filter_params)
    scope = apply_search(scope, params[:search].to_s.strip) if params[:search].present?
    scope = apply_sort_join(scope)
    preloads = [:violations_summary, :demographic, :environmental_justice,
      :funding_summary, :watershed_hazard, :boil_water_summary]
    @pagy, @systems = pagy(scope.preload(preloads).order(order_clause))
    @columns = visible_columns
    render partial: "home/table"
  end

  private

  def visible_columns
    return ColumnRegistry.columns if params[:cols].blank?
    selected = params[:cols].split(",").map(&:to_sym).to_set
    pinned, selectable = ColumnRegistry.columns.partition(&:pinned)
    pinned + selectable.select { |c| selected.include?(c.key) }
  end

  def filter_params
    FilterParams.permit(params)
  end

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
