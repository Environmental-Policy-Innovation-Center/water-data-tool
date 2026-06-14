module PublicWaterSystems
  class StatsController < ApplicationController
    def show
      scope = PublicWaterSystem.apply_filters(FilterParams.permit(params))
      unfiltered_total = PublicWaterSystem.count(:pwsid)
      @summary = PublicWaterSystem.build_summary(scope).merge(unfiltered_total: unfiltered_total)
      @summary_title = summary_title
      render layout: false
    end

    private

    def summary_title
      state_name = if params[:state].present?
        CartographicState.find_by(stusps: params[:state])&.name
      else
        params[:state_name].presence
      end

      state_name.present? ? "#{state_name}: Summary Statistics" : "Summary Statistics"
    end
  end
end
