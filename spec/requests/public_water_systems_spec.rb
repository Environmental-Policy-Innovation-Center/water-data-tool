require "rails_helper"
require "csv"
require "zlib"

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

  describe "GET /public_water_systems/export" do
    context "with an unrecognized file_format" do
      it "falls back to CSV" do
        create(:public_water_system)

        get "/public_water_systems/export", params: {file_format: "invalid"}

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq("text/csv")
      end
    end

    context "CSV export (default)" do
      it "returns a CSV file with correct content headers" do
        create(:public_water_system)

        get "/public_water_systems/export"

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".csv")
      end

      it "includes the expected column headers in the first row" do
        create(:public_water_system)

        get "/public_water_systems/export"

        headers = CSV.parse(response.body).first
        expect(headers).to include("Utility Name", "Utility ID", "State", "Open violations", "Boil water notices")
      end

      it "includes one data row per matching system" do
        create_list(:public_water_system, 3)

        get "/public_water_systems/export"

        rows = CSV.parse(response.body)
        expect(rows.length).to eq(4) # 1 header + 3 data rows
      end

      it "respects active filters" do
        create(:public_water_system, stusps: "VT")
        create(:public_water_system, stusps: "OH")

        get "/public_water_systems/export", params: {state: "VT"}

        rows = CSV.parse(response.body)
        expect(rows.length).to eq(2) # 1 header + 1 data row
      end

      it "returns all matching records without pagination" do
        create_list(:public_water_system, 75)

        get "/public_water_systems/export"

        rows = CSV.parse(response.body)
        expect(rows.length).to eq(76) # 1 header + 75 data rows
      end
    end

    context "GeoJSON export" do
      it "returns a gzip-compressed response with correct content headers" do
        create(:public_water_system)

        get "/public_water_systems/export", params: {file_format: "geojson"}

        expect(response).to have_http_status(:ok)
        expect(response.headers["Content-Encoding"]).to eq("gzip")
        expect(response.content_type).to eq("application/json")
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".geojson")
      end

      it "decompresses to a valid GeoJSON FeatureCollection" do
        create(:public_water_system)

        get "/public_water_systems/export", params: {file_format: "geojson"}

        body = Zlib::GzipReader.new(StringIO.new(response.body)).read
        geojson = JSON.parse(body)
        expect(geojson["type"]).to eq("FeatureCollection")
        expect(geojson["features"]).to be_an(Array)
        expect(geojson["features"].length).to eq(1)
      end

      it "includes pwsid in feature properties" do
        pws = create(:public_water_system)

        get "/public_water_systems/export", params: {file_format: "geojson"}

        body = Zlib::GzipReader.new(StringIO.new(response.body)).read
        feature = JSON.parse(body)["features"].first
        expect(feature["properties"]["pwsid"]).to eq(pws.pwsid)
      end

      it "respects active filters" do
        create(:public_water_system, stusps: "VT")
        create(:public_water_system, stusps: "OH")

        get "/public_water_systems/export", params: {file_format: "geojson", state: "VT"}

        body = Zlib::GzipReader.new(StringIO.new(response.body)).read
        geojson = JSON.parse(body)
        expect(geojson["features"].length).to eq(1)
      end
    end
  end

  describe "GET /public_water_systems/stats" do
    it "returns 200" do
      get stats_public_water_systems_path

      expect(response).to have_http_status(:ok)
    end

    it "renders a turbo-frame with id=stats-bar" do
      get stats_public_water_systems_path

      expect(response.body).to include('id="stats-bar"')
    end

    it "renders all four stats when data is fully populated" do
      pws1 = create(:public_water_system, population_served_count: 5_000, open_health_viol: "Yes")
      create(:demographic, public_water_system: pws1, pwsid: pws1.pwsid, median_household_income: 62_000)
      pws2 = create(:public_water_system, population_served_count: 3_500, open_health_viol: "No")
      create(:demographic, public_water_system: pws2, pwsid: pws2.pwsid, median_household_income: 78_000)

      get stats_public_water_systems_path

      expect(response.body).to include("Systems: 2 of 2")
      expect(response.body).to include("Customers served: 8,500")
      expect(response.body).to include("Area Median Income: ~$70,000")
      expect(response.body).to include("Open health violations: 1")
    end

    it "recalculates all stats to reflect the active filter" do
      gw = create(:public_water_system, gw_sw_code: "Groundwater", population_served_count: 3_000, open_health_viol: "Yes")
      create(:demographic, public_water_system: gw, pwsid: gw.pwsid, median_household_income: 55_000)
      create(:public_water_system, gw_sw_code: "Surface Water", population_served_count: 9_000, open_health_viol: "No")

      get stats_public_water_systems_path, params: {gw_sw_code: "Groundwater"}

      expect(response.body).to include("Systems: 1 of 2")
      expect(response.body).to include("Customers served: 3,000")
      expect(response.body).to include("Area Median Income: ~$55,000")
      expect(response.body).to include("Open health violations: 1")
    end

    context "edge cases" do
      it "renders 0 of N when no systems match the active filter" do
        create(:public_water_system, gw_sw_code: "Groundwater")

        get stats_public_water_systems_path, params: {gw_sw_code: "Surface Water"}

        expect(response.body).to include("Systems: 0 of 1")
      end

      it "renders 0 open health violations when no systems have violations" do
        create(:public_water_system, open_health_viol: "No")

        get stats_public_water_systems_path

        expect(response.body).to include("Open health violations: 0")
      end

      it "renders 0 customers served when all population counts are zero" do
        create(:public_water_system, population_served_count: 0)

        get stats_public_water_systems_path

        expect(response.body).to include("Customers served: 0")
      end

      it "renders no value for customers served when population data is nil" do
        create(:public_water_system, population_served_count: nil)

        get stats_public_water_systems_path

        expect(response.body).to include("Customers served:")
        expect(response.body).not_to match(/Customers served: \d/)
      end

      it "renders N/A for area median income when no demographics exist" do
        create(:public_water_system)

        get stats_public_water_systems_path

        expect(response.body).to include("Area Median Income: N/A")
      end
    end
  end

  describe "GET /public_water_systems/:pwsid" do
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
        get "/public_water_systems/DOESNOTEXIST", as: :json

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
        get "/public_water_systems/DOESNOTEXIST"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
