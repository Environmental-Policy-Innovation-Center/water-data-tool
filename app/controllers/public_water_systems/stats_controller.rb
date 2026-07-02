module PublicWaterSystems
  class StatsController < ApplicationController
    def show
      scope = PublicWaterSystem.apply_filters(FilterParams.permit(params))
      @summary = PublicWaterSystem.build_summary(scope).merge(unfiltered_total: scoped_total)
      @summary_title = summary_title
      render layout: false
    end

    private

    def scoped_total
      return PublicWaterSystem.count(:pwsid) if params[:state].blank?
      PublicWaterSystem.where(stusps: params[:state]).count(:pwsid)
    end

    def summary_title
      # Name comes from the canonical stusps lookup, not client-supplied params[:state_name] —
      # that value is untrusted and can be stale/mismatched (state=VT + state_name=Texas → "Vermont").
      state_name = if params[:state].present?
        CartographicState.find_by(stusps: params[:state])&.name
      else
        params[:state_name].presence
      end

      state_name.present? ? "#{state_name}: Summary Statistics" : "Summary Statistics"
    end
  end
end
