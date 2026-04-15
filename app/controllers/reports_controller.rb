class ReportsController < ApplicationController
  def show
    @pws = PublicWaterSystem
      .with_details
      .find_by(pwsid: params[:pwsid])

    if @pws
      render layout: false
    else
      render plain: "Not found", status: :not_found
    end
  end
end
