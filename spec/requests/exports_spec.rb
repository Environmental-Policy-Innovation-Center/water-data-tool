require "rails_helper"
require "csv"

RSpec.describe "Exports", type: :request do
  describe "GET /export" do
    context "with an unrecognized file_format" do
      it "falls back to CSV" do
        create(:public_water_system)

        get export_path, params: {file_format: "invalid"}

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq("text/csv")
      end
    end

    context "CSV export (default)" do
      it "returns a CSV file with correct content headers" do
        create(:public_water_system)

        get export_path

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq("text/csv")
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".csv")
      end

      it "includes the expected column headers in the first row" do
        create(:public_water_system)

        get export_path

        headers = CSV.parse(response.body).first
        expect(headers).to include("Utility Name", "Utility ID", "State", "Has open violations", "Boil water notices")
      end

      it "includes one data row per matching system" do
        create_list(:public_water_system, 3)

        get export_path

        rows = CSV.parse(response.body)
        expect(rows.length).to eq(4) # 1 header + 3 data rows
      end

      it "respects active filters" do
        create(:public_water_system, stusps: "VT")
        create(:public_water_system, stusps: "OH")

        get export_path, params: {state: "VT"}

        rows = CSV.parse(response.body)
        expect(rows.length).to eq(2) # 1 header + 1 data row
      end

      it "returns all matching records without pagination" do
        create_list(:public_water_system, 75)

        get export_path

        rows = CSV.parse(response.body)
        expect(rows.length).to eq(76) # 1 header + 75 data rows
      end
    end

    context "with specific IDs selected" do
      it "exports only the specified records as CSV" do
        pws1 = create(:public_water_system)
        create(:public_water_system)

        get export_path, params: {pwsids: [pws1.pwsid]}

        rows = CSV.parse(response.body)
        expect(rows.length).to eq(2) # 1 header + 1 data row
      end

      it "exports only the specified records as GeoJSON" do
        pws1 = create(:public_water_system)
        create(:public_water_system)

        get export_path, params: {pwsids: [pws1.pwsid], file_format: "geojson"}

        body = Zlib::GzipReader.new(StringIO.new(response.body)).read
        expect(JSON.parse(body)["features"].length).to eq(1)
      end

      it "silently ignores unknown pwsids and returns only matching records" do
        pws = create(:public_water_system)

        get export_path, params: {pwsids: [pws.pwsid, "NONEXISTENT"]}

        rows = CSV.parse(response.body)
        expect(rows.length).to eq(2) # 1 header + 1 data row for the valid ID
      end

      it "caps the query at 500 IDs" do
        pws = create(:public_water_system)
        ids = Array.new(501) { |i| "FAKE#{i.to_s.rjust(7, "0")}" }
        ids[0] = pws.pwsid

        get export_path, params: {pwsids: ids}

        rows = CSV.parse(response.body)
        expect(rows.length).to eq(2) # 1 header + 1 matching record; 501st ID was dropped
      end
    end

    context "GeoJSON export" do
      it "returns a response with correct content headers" do
        create(:public_water_system)

        get export_path, params: {file_format: "geojson"}

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")
        expect(response.headers["Content-Disposition"]).to include("attachment")
        expect(response.headers["Content-Disposition"]).to include(".geojson")
      end

      it "returns a valid GeoJSON FeatureCollection" do
        create(:public_water_system)

        get export_path, params: {file_format: "geojson"}

        geojson = JSON.parse(response.body)
        expect(geojson["type"]).to eq("FeatureCollection")
        expect(geojson["features"]).to be_an(Array)
        expect(geojson["features"].length).to eq(1)
      end

      it "includes pwsid in feature properties" do
        pws = create(:public_water_system)

        get export_path, params: {file_format: "geojson"}

        feature = JSON.parse(response.body)["features"].first
        expect(feature["properties"]["pwsid"]).to eq(pws.pwsid)
      end

      it "respects active filters" do
        create(:public_water_system, stusps: "VT")
        create(:public_water_system, stusps: "OH")

        get export_path, params: {file_format: "geojson", state: "VT"}

        geojson = JSON.parse(response.body)
        expect(geojson["features"].length).to eq(1)
      end
    end
  end
end
