require "rails_helper"

RSpec.describe "Stats", type: :request do
  describe "GET /stats" do
    it "returns 200" do
      get stats_path

      expect(response).to have_http_status(:ok)
    end

    it "renders a turbo-frame with id=stats-bar" do
      get stats_path

      expect(response.body).to include('id="stats-bar"')
    end

    it "renders all four stats when data is fully populated" do
      pws1 = create(:public_water_system, population_served_count: 5_000, open_health_viol: true)
      create(:demographic, public_water_system: pws1, pwsid: pws1.pwsid, median_household_income: 62_000)
      pws2 = create(:public_water_system, population_served_count: 3_500, open_health_viol: false)
      create(:demographic, public_water_system: pws2, pwsid: pws2.pwsid, median_household_income: 78_000)

      get stats_path

      expect(response.body).to include("Systems: 2 of 2")
      expect(response.body).to include("Customers served: 8,500")
      expect(response.body).to include("Area Median Income: ~$70,000")
      expect(response.body).to include("Open health violations: 1")
    end

    it "recalculates all stats to reflect the active filter" do
      gw = create(:public_water_system, gw_sw_code: "Groundwater", population_served_count: 3_000, open_health_viol: true)
      create(:demographic, public_water_system: gw, pwsid: gw.pwsid, median_household_income: 55_000)
      create(:public_water_system, gw_sw_code: "Surface Water", population_served_count: 9_000, open_health_viol: false)

      get stats_path, params: {gw_sw_code: "Groundwater"}

      expect(response.body).to include("Systems: 1 of 2")
      expect(response.body).to include("Customers served: 3,000")
      expect(response.body).to include("Area Median Income: ~$55,000")
      expect(response.body).to include("Open health violations: 1")
    end

    it "renders a state-scoped summary heading and composes state with active filters" do
      create(:cartographic_state, stusps: "TX", name: "Texas")
      tx_groundwater = create(:public_water_system, stusps: "TX", gw_sw_code: "Groundwater", population_served_count: 3_000)
      create(:demographic, public_water_system: tx_groundwater, pwsid: tx_groundwater.pwsid, median_household_income: 55_000)
      create(:public_water_system, stusps: "TX", gw_sw_code: "Surface Water", population_served_count: 9_000)
      create(:public_water_system, stusps: "VT", gw_sw_code: "Groundwater", population_served_count: 12_000)

      get stats_path, params: {state: "TX", state_name: "Texas", gw_sw_code: "Groundwater"}

      expect(response.body).to include("Texas: Summary Statistics")
      expect(response.body).to include("Systems: 1 of 3")
      expect(response.body).to include("Customers served: 3,000")
    end

    it "derives the state-scoped summary heading from the state filter" do
      create(:cartographic_state, stusps: "VT", name: "Vermont")
      create(:public_water_system, stusps: "VT")

      get stats_path, params: {state: "VT", state_name: "Texas"}

      expect(response.body).to include("Vermont: Summary Statistics")
      expect(response.body).not_to include("Texas: Summary Statistics")
    end

    context "edge cases" do
      it "renders 0 of N when no systems match the active filter" do
        create(:public_water_system, gw_sw_code: "Groundwater")

        get stats_path, params: {gw_sw_code: "Surface Water"}

        expect(response.body).to include("Systems: 0 of 1")
      end

      it "renders 0 open health violations when no systems have violations" do
        create(:public_water_system, open_health_viol: false)

        get stats_path

        expect(response.body).to include("Open health violations: 0")
      end

      it "renders 0 customers served when all population counts are zero" do
        create(:public_water_system, population_served_count: 0)

        get stats_path

        expect(response.body).to include("Customers served: 0")
      end

      it "renders no value for customers served when population data is nil" do
        create(:public_water_system, population_served_count: nil)

        get stats_path

        expect(response.body).to include("Customers served:")
        expect(response.body).not_to match(/Customers served: \d/)
      end

      it "renders N/A for area median income when no demographics exist" do
        create(:public_water_system)

        get stats_path

        expect(response.body).to include("Area Median Income: N/A")
      end
    end
  end
end
