class HomeController < ApplicationController
  include Sortable

  def index
    @last_updated = DataImport.maximum(:imported_at)
    @column_state = column_state
    @visible_col_keys = @column_state.visible_col_keys
    @panel_groups = ColumnRegistry.panel_groups(col_keys: @column_state.panel_col_keys)
  end

  def map
    scope = PublicWaterSystem.apply_filters(filter_params)
    render json: {pwsids: scope.pluck(:pwsid)}
  end

  def table
    @search_term = decoded_state["search"].to_s.strip
    scope = PublicWaterSystem.apply_filters(filter_params)
    scope = apply_search(scope, @search_term) if @search_term.present?
    scope = apply_sort_join(scope)
    preloads = [:violations_summary, :demographic, :trend_datum, :environmental_justice,
      :funding_summary, :watershed_hazard, :boil_water_summary]
    @pagy, @systems = pagy(scope.preload(preloads).order(order_clause))
    @columns = visible_columns
    render partial: "home/table"
  end

  private

  def visible_columns
    ColumnRegistry.visible(keys: column_state.visible_col_keys)
  end

  def parse_cols_param
    column_state.visible_col_keys
  end

  def column_state
    @column_state ||= ColumnRegistry.parse_column_state(decoded_state["cols"])
  end

  def filter_params
    encoded_filters = ActionController::Parameters
      .new(decoded_state["filters"] || {})
      .permit(*FilterRegistry.permit_arguments)
      .to_h
    direct_filters = FilterParams.permit(params).to_h

    ActionController::Parameters.new(encoded_filters.merge(direct_filters)).permit(*FilterRegistry.permit_arguments)
  end

  def decoded_state
    @decoded_state ||= UrlStateCodec.decode(params[:encoded])
  end
end
