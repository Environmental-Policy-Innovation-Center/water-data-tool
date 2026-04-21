class PublicWaterSystemsController < ApplicationController
  SORTABLE_COLUMNS = %w[
    pwsid pws_name stusps pop_cat_5 population_served_count
    service_connections_count gw_sw_code owner_type primacy_type
    service_area_type symbology_field area_sq_miles open_health_viol
  ].freeze

  def index
    scope = PublicWaterSystem.apply_filters(params)
    scope = apply_sort(scope)
    @pagy, systems = pagy(:offset, scope)

    render json: {
      total_count: @pagy.count,
      page: @pagy.page,
      per_page: @pagy.limit,
      results: systems.map { |pws| PublicWaterSystemSerializer.new(pws).serialize },
      summary: PublicWaterSystem.build_summary(scope)
    }
  end

  def show
    @pws = PublicWaterSystem
      .with_details
      .find_by(pwsid: params[:pwsid])

    unless @pws
      respond_to do |format|
        format.html { render plain: "Not found", status: :not_found }
        format.json { render json: {error: "Public water system not found"}, status: :not_found }
      end
      return
    end

    respond_to do |format|
      format.html { render layout: false }
      format.json { render json: PublicWaterSystemDetailSerializer.new(@pws).serialize }
    end
  end

  private

  def apply_sort(scope)
    column = SORTABLE_COLUMNS.include?(params[:sort_by]) ? params[:sort_by] : "pwsid"
    direction = (params[:sort_dir]&.downcase == "desc") ? :desc : :asc
    scope.order(column => direction)
  end
end
