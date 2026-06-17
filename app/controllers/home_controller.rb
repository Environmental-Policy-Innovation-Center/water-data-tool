class HomeController < ApplicationController
  include Sortable

  def index
    @last_updated = DataImport.maximum(:imported_at)
    @visible_col_keys = parse_cols_param
    @column_categories = ColumnRegistry.categories
    @cols_by_category = ColumnRegistry.columns_by_category
  end

  def map
    scope = PublicWaterSystem.apply_filters(filter_params)
    render json: {pwsids: scope.pluck(:pwsid)}
  end

  def table
    scope = PublicWaterSystem.apply_filters(filter_params)
    scope = apply_search(scope, params[:search].to_s.strip) if params[:search].present?
    scope = apply_sort_join(scope)
    preloads = [:violations_summary, :demographic, :trend_datum, :environmental_justice,
      :funding_summary, :watershed_hazard, :boil_water_summary]
    @pagy, @systems = pagy(scope.preload(preloads).order(order_clause))
    @columns = visible_columns
    render partial: "home/table"
  end

  private

  def visible_columns
    ColumnRegistry.visible(keys: parse_cols_param)
  end

  def parse_cols_param
    ColumnRegistry.parse_keys(decoded_state["cols"])&.to_set
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
