module PublicWaterSystems
  class ReportsController < ApplicationController
    def show
      @pws = PublicWaterSystem
        .with_details
        .find_by(pwsid: params[:pwsid])
      if @pws
        @from_map = !turbo_frame_request? && begin
          URI.parse(request.referer.to_s).host == request.host
        rescue URI::InvalidURIError
          false
        end
        render layout: (turbo_frame_request? ? false : "report")
      else
        render plain: "Not found", status: :not_found
      end
    end
  end
end
