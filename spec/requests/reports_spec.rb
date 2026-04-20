require "rails_helper"

RSpec.describe "Reports", type: :request do
  describe "GET /public_water_systems/:pwsid/report" do
    it "returns 200 with a report-body turbo frame" do
      pws = create(:public_water_system)

      get "/public_water_systems/#{pws.pwsid}/report"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="report-body"')
    end

    it "renders the system name and all section headings" do
      pws = create(:public_water_system, pws_name: "Clearwater Co")

      get "/public_water_systems/#{pws.pwsid}/report"

      expect(response.body).to include("Clearwater Co")
      %w[Overview Demographics Violations Funding].each do |heading|
        expect(response.body).to include(heading)
      end
    end

    it "handles nil associations gracefully" do
      pws = create(:public_water_system)

      get "/public_water_systems/#{pws.pwsid}/report"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Data not available")
    end

    it "renders populated association data when present" do
      pws = create(:public_water_system)
      create(:demographic, pwsid: pws.pwsid, total_population: 75_000)
      create(:violations_summary, pwsid: pws.pwsid, health_violations_5yr: 3)

      get "/public_water_systems/#{pws.pwsid}/report"

      expect(response.body).to include("75,000")
      expect(response.body).to include("3")
    end

    it "returns 404 when the system does not exist" do
      get "/public_water_systems/ZZ0000000/report"

      expect(response).to have_http_status(:not_found)
    end
  end
end
