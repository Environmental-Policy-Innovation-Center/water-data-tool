class TilesController < ApplicationController
  def show
    z = params[:z].to_i
    x = params[:x].to_i
    y = params[:y].to_i

    raise ActionController::BadRequest, "z out of range" unless z.between?(0, 22)
    raise ActionController::BadRequest, "x out of range" unless x.between?(0, (2**z) - 1)
    raise ActionController::BadRequest, "y out of range" unless y.between?(0, (2**z) - 1)

    mvt_binary = TileGenerator.build_tile(z, x, y)

    response.headers["Cache-Control"] = "public, max-age=600"
    send_data mvt_binary, type: "application/x-protobuf", disposition: "inline"
  end
end
