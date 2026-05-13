require "rails_helper"

RSpec.describe "PublicWaterSystems", type: :request do
  describe "GET /public_water_systems" do
    context "with no filters" do
      it "returns 200 with pagination envelope" do
        create_list(:public_water_system, 3)

        get "/public_water_systems"

        json = response.parsed_body

        expect(response).to have_http_status(:ok)
        expect(json["total_count"]).to eq(3)
        expect(json["page"]).to eq(1)
        expect(json["per_page"]).to eq(50)
        expect(json["results"].length).to eq(3)
        expect(json["summary"].keys).to match_array(%w[
          systems_count total_population_served
          systems_with_open_violations avg_median_household_income
        ])
      end

      it "includes expected fields in each result" do
        create(:public_water_system)

        get "/public_water_systems"

        result = response.parsed_body["results"].first
        expect(result.keys).to match_array(%w[
          pwsid pws_name stusps primacy_agency pop_cat_5
          population_served_count service_connections_count gw_sw_code
          owner_type primacy_type service_area_type area_sq_miles
          open_health_viol is_wholesaler is_school_or_daycare counties
        ])
      end
    end

    context "with pagination params" do
      it "limits results to per_page and reports total_count across all pages" do
        create_list(:public_water_system, 5)

        get "/public_water_systems", params: {per_page: 2, page: 1}

        json = response.parsed_body
        expect(json["results"].length).to eq(2)
        expect(json["total_count"]).to eq(5)
        expect(json["per_page"]).to eq(2)
      end

      it "returns the requested page" do
        create_list(:public_water_system, 5)

        get "/public_water_systems", params: {per_page: 2, page: 2}

        json = response.parsed_body
        expect(json["results"].length).to eq(2)
        expect(json["page"]).to eq(2)
      end
    end

    context "with sort params" do
      it "ignores sort_by values not in SORTABLE_COLUMNS allowlist (SQL injection guard)" do
        create_list(:public_water_system, 2)

        get "/public_water_systems", params: {sort_by: "DROP TABLE public_water_systems"}

        # The injected string never reaches SQL — SORTABLE_COLUMNS allowlist silently falls back to pwsid.
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["results"].length).to eq(2)
      end

      it "sorts ascending by the requested column" do
        create(:public_water_system, pws_name: "Zebra Water")
        create(:public_water_system, pws_name: "Alpha Water")

        get "/public_water_systems", params: {sort_by: "pws_name", sort_dir: "asc"}

        names = response.parsed_body["results"].map { |r| r["pws_name"] }
        expect(names).to eq(names.sort)
      end

      it "sorts descending when sort_dir is desc" do
        create(:public_water_system, pws_name: "Zebra Water")
        create(:public_water_system, pws_name: "Alpha Water")

        get "/public_water_systems", params: {sort_by: "pws_name", sort_dir: "desc"}

        names = response.parsed_body["results"].map { |r| r["pws_name"] }
        expect(names).to eq(names.sort.reverse)
      end
    end

    context "with filter params" do
      it "returns only systems matching the filter" do
        groundwater = create(:public_water_system, gw_sw_code: "Groundwater")
        create(:public_water_system, gw_sw_code: "Surface Water")

        get "/public_water_systems", params: {gw_sw_code: "Groundwater"}

        json = response.parsed_body
        expect(json["total_count"]).to eq(1)
        expect(json["results"].first["pwsid"]).to eq(groundwater.pwsid)
      end
    end

    context "with summary" do
      it "returns correct summary counts when a sort is active" do
        create(:public_water_system, open_health_viol: "Yes", population_served_count: 1000)
        create(:public_water_system, open_health_viol: "No", population_served_count: 500)

        get "/public_water_systems", params: {sort_by: "pws_name", sort_dir: "asc"}

        summary = response.parsed_body["summary"]
        expect(summary["systems_count"]).to eq(2)
        expect(summary["total_population_served"]).to eq(1500)
        expect(summary["systems_with_open_violations"]).to eq(1)
      end

      it "returns correct summary counts for the filtered scope" do
        create(:public_water_system, open_health_viol: "Yes", population_served_count: 1000, stusps: "VT")
        create(:public_water_system, open_health_viol: "No", population_served_count: 500, stusps: "VT")
        create(:public_water_system, open_health_viol: "No", population_served_count: 200, stusps: "OH")

        get "/public_water_systems", params: {state: "VT"}

        summary = response.parsed_body["summary"]
        expect(summary["systems_count"]).to eq(2)
        expect(summary["total_population_served"]).to eq(1500)
        expect(summary["systems_with_open_violations"]).to eq(1)
      end
    end
  end

  describe "GET /public_water_systems/:pwsid" do
    context "pwsid routing constraints" do
      it "routes tribal systems with numeric EPA region prefix" do
        pws = create(:public_water_system, pwsid: "084690440")

        get "/public_water_systems/#{pws.pwsid}", as: :json

        expect(response).to have_http_status(:ok)
      end

      it "routes Utah-style systems with letters in the system-number portion" do
        pws = create(:public_water_system, pwsid: "UTAH01001")

        get "/public_water_systems/#{pws.pwsid}", as: :json

        expect(response).to have_http_status(:ok)
      end

      it "routes compound systems whose pwsid is multiple IDs joined by '; '" do
        pws = build(:public_water_system, pwsid: "ND3401128; ND1001380; ND4801479")
        pws.save!(validate: false)

        get "/public_water_systems/ND3401128;%20ND1001380;%20ND4801479", as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context "when requesting JSON" do
      it "returns 200 with top-level PWS fields" do
        pws = create(:public_water_system)

        get "/public_water_systems/#{pws.pwsid}", as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["pwsid"]).to eq(pws.pwsid)
        expect(json["pws_name"]).to eq(pws.pws_name)
      end

      it "includes all association keys in the response" do
        pws = create(:public_water_system)

        get "/public_water_systems/#{pws.pwsid}", as: :json

        json = response.parsed_body
        expect(json.keys).to include(
          "demographic", "violations_summary", "environmental_justice",
          "funding_summary", "watershed_hazard", "boil_water_summary", "trend_datum"
        )
      end

      it "returns null for associations not yet populated by ETL" do
        pws = create(:public_water_system)

        get "/public_water_systems/#{pws.pwsid}", as: :json

        json = response.parsed_body
        expect(json["demographic"]).to be_nil
        expect(json["violations_summary"]).to be_nil
        expect(json["environmental_justice"]).to be_nil
        expect(json["funding_summary"]).to be_nil
        expect(json["watershed_hazard"]).to be_nil
        expect(json["boil_water_summary"]).to be_nil
        expect(json["trend_datum"]).to be_nil
      end

      it "returns 404 when the pwsid does not exist" do
        get "/public_water_systems/ZZ0000000", as: :json

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]).to be_present
      end
    end

    context "when requesting HTML" do
      it "returns 200 with the detail page" do
        pws = create(:public_water_system)

        get "/public_water_systems/#{pws.pwsid}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('class="pws-detail"')
      end

      it "renders the system name and ID" do
        pws = create(:public_water_system, pws_name: "Green Mountain Water")

        get "/public_water_systems/#{pws.pwsid}"

        expect(response.body).to include("Green Mountain Water")
        expect(response.body).to include(pws.pwsid)
      end

      it "renders section headings for all data groups" do
        pws = create(:public_water_system)

        get "/public_water_systems/#{pws.pwsid}"

        %w[Overview Demographics Violations Funding].each do |heading|
          expect(response.body).to include(heading)
        end
      end

      it "handles nil associations gracefully" do
        pws = create(:public_water_system)

        get "/public_water_systems/#{pws.pwsid}"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Data not available")
      end

      it "renders populated association data when present" do
        pws = create(:public_water_system)
        create(:demographic, pwsid: pws.pwsid, total_population: 42_000)

        get "/public_water_systems/#{pws.pwsid}"

        expect(response.body).to include("42,000")
      end

      it "returns 404 when the pwsid does not exist" do
        get "/public_water_systems/ZZ0000000"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
