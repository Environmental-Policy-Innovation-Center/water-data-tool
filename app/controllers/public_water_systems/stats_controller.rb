module PublicWaterSystems
  class StatsController < ApplicationController
    def show
      scope = PublicWaterSystem.apply_filters(params)
      unfiltered_total = PublicWaterSystem.count(:pwsid)
      @summary = PublicWaterSystem.build_summary(scope).merge(unfiltered_total: unfiltered_total)
      render layout: false
    end
  end
end
