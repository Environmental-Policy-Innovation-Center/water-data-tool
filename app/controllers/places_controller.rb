class PlacesController < ApplicationController
  def search
    if params[:q].blank?
      render json: []
      return
    end

    places = CartographicPlace
      .where("name ILIKE ?", "#{sanitize_like(params[:q])}%")
      .order(:name, :stusps)
      .limit(10)
      .select(:geoid, :name, :stusps)

    response.headers["Cache-Control"] = "public, max-age=3600"
    render json: places.map { |p| {geoid: p.geoid, name: p.name, stusps: p.stusps} }
  end

  private

  def sanitize_like(term)
    term.gsub(/[%_\\]/) { |c| "\\#{c}" }
  end
end
