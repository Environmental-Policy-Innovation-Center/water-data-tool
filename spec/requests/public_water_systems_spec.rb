require "rails_helper"
require "csv"
require "zlib"

RSpec.describe "PublicWaterSystems", type: :request do
  describe "GET /public_water_systems" do
    context "with no filters" do
      it "returns 200 with pagination envelope" do
        create_list(:public_water_system, 3)

        get "/public_water_systems"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["total_count"]).to eq(3)
        expect(json["page"]).to eq(1)
        expect(json["per_page"]).to eq(50)
        expect(json["results"].length).to eq(3)
        expect(json["summary"].keys).to match_array(%w[systems_count total_population_served systems_with_open_violations])
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

  describe "GET /public_water_systems/:pwsid" do
    context "when the system exists" do
      it "returns 200 with top-level PWS fields" do
        pws = create(:public_water_system)

        get "/public_water_systems/#{pws.pwsid}"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["pwsid"]).to eq(pws.pwsid)
        expect(json["pws_name"]).to eq(pws.pws_name)
      end

      it "includes all association keys in the response" do
        pws = create(:public_water_system)

        get "/public_water_systems/#{pws.pwsid}"

        json = response.parsed_body
        expect(json.keys).to include(
          "demographic", "violations_summary", "environmental_justice",
          "funding_summary", "watershed_hazard", "boil_water_summary", "trend_datum"
        )
      end

      it "returns null for associations not yet populated by ETL" do
        pws = create(:public_water_system)

        get "/public_water_systems/#{pws.pwsid}"

        json = response.parsed_body
        expect(json["demographic"]).to be_nil
        expect(json["violations_summary"]).to be_nil
        expect(json["environmental_justice"]).to be_nil
        expect(json["funding_summary"]).to be_nil
        expect(json["watershed_hazard"]).to be_nil
        expect(json["boil_water_summary"]).to be_nil
        expect(json["trend_datum"]).to be_nil
      end
    end

    context "when the pwsid does not exist" do
      it "returns 404 with a JSON error body" do
        get "/public_water_systems/DOESNOTEXIST"

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]).to be_present
      end
    end
  end
end
