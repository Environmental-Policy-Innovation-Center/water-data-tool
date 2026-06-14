class StatesController < ApplicationController
  def lookup
    unless params[:lng].present? && params[:lat].present?
      render json: {error: "missing_coordinates"}, status: :bad_request
      return
    end

    lng = Float(params[:lng])
    lat = Float(params[:lat])
    unless valid_coordinate?(lng, lat)
      render json: {error: "invalid_coordinates"}, status: :bad_request
      return
    end

    state = CartographicState.containing_point(lng:, lat:).first

    if state
      render json: {stusps: state.stusps, name: state.name, geoid: state.geoid}
    else
      render json: {error: "state_not_found"}, status: :not_found
    end
  rescue ArgumentError
    render json: {error: "invalid_coordinates"}, status: :bad_request
  end

  private

  def valid_coordinate?(lng, lat)
    lng.finite? && lat.finite? && lng.between?(-180, 180) && lat.between?(-90, 90)
  end
end
