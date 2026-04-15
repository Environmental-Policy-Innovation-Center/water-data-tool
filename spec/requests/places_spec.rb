require "rails_helper"

RSpec.describe "Places", type: :request do
  describe "GET /places/search" do
    it "returns matching places as JSON" do
      create(:cartographic_place, name: "Burlington", stusps: "VT", geoid: "5010675")

      get "/places/search", params: {q: "Burl"}

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.length).to eq(1)
      expect(json.first["name"]).to eq("Burlington")
      expect(json.first["stusps"]).to eq("VT")
      expect(json.first["geoid"]).to eq("5010675")
    end

    it "returns empty array when no matches" do
      get "/places/search", params: {q: "Zzzzz"}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "limits results to 10" do
      15.times { |i| create(:cartographic_place, name: "Springfield", geoid: "50#{10000 + i}") }

      get "/places/search", params: {q: "Spring"}

      expect(response.parsed_body.length).to be <= 10
    end

    it "escapes LIKE special characters in the query" do
      create(:cartographic_place, name: "100% Pure Water", geoid: "5099999")

      get "/places/search", params: {q: "100%"}

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.length).to eq(1)
      expect(json.first["name"]).to eq("100% Pure Water")
    end

    it "returns empty array when q param is missing" do
      get "/places/search"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end
  end
end
