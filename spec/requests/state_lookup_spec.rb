require "rails_helper"

RSpec.describe "State lookup", type: :request do
  let(:next_gid) { CartographicState.maximum(:gid).to_i + 1 }

  def insert_state(stusps:, name:, wkt:)
    conn = ApplicationRecord.connection
    geoid = (stusps == "TX") ? "48" : "50"
    conn.execute(<<~SQL.squish)
      INSERT INTO cartographic_states (gid, stusps, geoid, name, statefp, geom)
      VALUES (
        #{next_gid},
        #{conn.quote(stusps)},
        #{conn.quote(geoid)},
        #{conn.quote(name)},
        #{conn.quote(geoid)},
        ST_Multi(ST_GeomFromText(#{conn.quote(wkt)}, 4326))
      )
    SQL
  end

  describe "GET /states/lookup" do
    it "returns the state containing the requested longitude and latitude" do
      insert_state(
        stusps: "TX",
        name: "Texas",
        wkt: "POLYGON((-101 29,-99 29,-99 31,-101 31,-101 29))"
      )

      get state_lookup_path, params: {lng: -100, lat: 30}

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include(
        "stusps" => "TX",
        "name" => "Texas",
        "geoid" => "48"
      )
    end

    it "returns not found when the point is outside known state geometries" do
      insert_state(
        stusps: "TX",
        name: "Texas",
        wkt: "POLYGON((-101 29,-99 29,-99 31,-101 31,-101 29))"
      )

      get state_lookup_path, params: {lng: -90, lat: 30}

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)).to eq("error" => "state_not_found")
    end

    it "rejects missing coordinates" do
      get state_lookup_path, params: {lng: -100}

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "missing_coordinates")
    end

    it "rejects non-finite coordinates" do
      get state_lookup_path, params: {lng: "NaN", lat: 30}

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "invalid_coordinates")
    end

    it "rejects coordinates outside longitude and latitude bounds" do
      get state_lookup_path, params: {lng: -181, lat: 30}

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "invalid_coordinates")
    end
  end
end
