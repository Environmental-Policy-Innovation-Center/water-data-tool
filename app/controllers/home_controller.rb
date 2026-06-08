class HomeController < ApplicationController
  include Sortable

  def index
    @last_updated = DataImport.maximum(:imported_at)
    @visible_col_keys = params[:cols].blank? ? nil : params[:cols].split(",").map(&:to_sym).to_set
    @pinned_cols, @toggleable_cols = ColumnRegistry.columns.partition(&:pinned)
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
    keys = params[:cols].blank? ? nil : params[:cols].split(",").map(&:to_sym).to_set
    ColumnRegistry.visible(keys: keys)
  end

  def filter_params
    FilterParams.permit(params)
  end
end
