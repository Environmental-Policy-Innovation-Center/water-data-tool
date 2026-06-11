require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "returns 200" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "renders the downloads section with a national download link" do
      get root_path
      expect(response.body).to include("national-dw-tool-staged.zip")
    end

    it "renders state download links" do
      get root_path
      expect(response.body).to include("states/CO.zip")
      expect(response.body).to include("Colorado")
      expect(response.body).to include("states/VT.zip")
      expect(response.body).to include("Vermont")
    end

    it "renders territory download links" do
      get root_path
      expect(response.body).to include("states/PR.zip")
      expect(response.body).to include("Puerto Rico")
      expect(response.body).to include("states/GU.zip")
      expect(response.body).to include("Guam")
    end

    it "renders the datasets catalog with all 27 dataset cards" do
      get root_path
      expect(response.body).to include("Community Water System Service Area Boundaries")
      expect(response.body).to include("Safe Drinking Water Information System")
      expect(response.body).to include("Texas Drinking Water Advisories")
      expect(response.body.scan("grid-item").count).to eq(27)
    end

    it "renders dataset source links and metadata" do
      get root_path
      expect(response.body).to include("Data source:")
      expect(response.body).to include("Update frequency:")
      expect(response.body).to include("Things you should know")
    end

    it "renders the datasets filter and sort controls" do
      get root_path
      expect(response.body).to include("data-controller=\"datasets\"")
      expect(response.body).to include("ds-dataSource")
    end
  end

  describe "GET /map" do
    it "returns all pwsids when no filters are applied" do
      systems = create_list(:public_water_system, 3)

      get map_path

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["pwsids"]).to match_array(systems.map(&:pwsid))
    end

    it "returns only pwsids matching filter params" do
      gw = create(:public_water_system, gw_sw_code: "Groundwater")
      sw = create(:public_water_system, gw_sw_code: "Surface Water")

      get map_path, params: {gw_sw_code: "Groundwater"}

      json = response.parsed_body
      expect(json["pwsids"]).to include(gw.pwsid)
      expect(json["pwsids"]).not_to include(sw.pwsid)
    end

    it "returns an empty array when no systems match the filters" do
      create(:public_water_system, gw_sw_code: "Groundwater")

      get map_path, params: {gw_sw_code: "Surface Water"}

      expect(response.parsed_body["pwsids"]).to eq([])
    end

    it "filters by health subcat range params through the controller" do
      match = create(:public_water_system)
      excluded = create(:public_water_system)
      create(:violations_summary, pwsid: match.pwsid, groundwater_rule_5yr: 5)
      create(:violations_summary, pwsid: excluded.pwsid, groundwater_rule_5yr: 1)

      get map_path, params: {groundwater_rule_5yr_min: 4, groundwater_rule_5yr_max: 10}

      json = response.parsed_body
      expect(json["pwsids"]).to include(match.pwsid)
      expect(json["pwsids"]).not_to include(excluded.pwsid)
    end

    it "filters by paperwork violations range params through the controller" do
      match = create(:public_water_system)
      excluded = create(:public_water_system)
      create(:violations_summary, pwsid: match.pwsid, paperwork_violations_5yr: 10)
      create(:violations_summary, pwsid: excluded.pwsid, paperwork_violations_5yr: 1)

      get map_path, params: {paperwork_violations_5yr_min: 5, paperwork_violations_5yr_max: 20}

      json = response.parsed_body
      expect(json["pwsids"]).to include(match.pwsid)
      expect(json["pwsids"]).not_to include(excluded.pwsid)
    end

    it "returns only a pwsids key — no other fields" do
      pws = create(:public_water_system)

      get map_path

      json = response.parsed_body
      expect(json.keys).to eq(["pwsids"])
      expect(json["pwsids"].first).to eq(pws.pwsid)
    end
  end

  describe "GET /table" do
    it "returns 200" do
      get table_path
      expect(response).to have_http_status(:ok)
    end

    it "renders a turbo-frame with id=data-table" do
      get table_path
      expect(response.body).to include('id="data-table"')
    end

    it "renders column headers" do
      get table_path
      expect(response.body).to include("Utility Name")
      expect(response.body).to include("State")
      expect(response.body).to include("County")
    end

    it "renders pws_name in the table body" do
      create(:public_water_system, pws_name: "Aloha Water")
      get table_path
      expect(response.body).to include("Aloha Water")
    end

    it "renders an EPA facility report link when present" do
      create(:public_water_system, pws_name: "Aloha Water", detailed_facility_report: "https://example.com/report")
      get table_path
      expect(response.body).to include("https://example.com/report")
    end

    it "sorts ascending by pws_name by default" do
      create(:public_water_system, pws_name: "Zebra Water")
      create(:public_water_system, pws_name: "Alpha Water")
      get table_path
      expect(response.body.index("Alpha Water")).to be < response.body.index("Zebra Water")
    end

    it "sorts descending when direction=desc" do
      create(:public_water_system, pws_name: "Alpha Water")
      create(:public_water_system, pws_name: "Zebra Water")
      get table_path, params: {sort: "pws_name", direction: "desc"}
      expect(response.body.index("Zebra Water")).to be < response.body.index("Alpha Water")
    end

    it "sorts by a valid non-default column" do
      create(:public_water_system, stusps: "AK", pws_name: "System A")
      create(:public_water_system, stusps: "ZZ", pws_name: "System Z")
      get table_path, params: {sort: "stusps", direction: "asc"}
      expect(response.body.index("System A")).to be < response.body.index("System Z")
    end

    it "falls back to pws_name sort for an unknown column" do
      create(:public_water_system, pws_name: "Alpha Water")
      create(:public_water_system, pws_name: "Zebra Water")
      get table_path, params: {sort: "nonexistent_column"}
      expect(response.body.index("Alpha Water")).to be < response.body.index("Zebra Water")
    end

    it "paginates — renders Next link when results exceed per_page" do
      create_list(:public_water_system, 55)
      get table_path, params: {per_page: 50}
      expect(response.body).to include("›")
      expect(response.body).to include("entries")
    end

    it "filters by gw_sw_code" do
      create(:public_water_system, gw_sw_code: "GW", pws_name: "Groundwater System")
      create(:public_water_system, gw_sw_code: "SW", pws_name: "Surface System")
      get table_path, params: {gw_sw_code: "GW"}
      expect(response.body).to include("Groundwater System")
      expect(response.body).not_to include("Surface System")
    end

    it "filters by selected state" do
      create(:public_water_system, stusps: "TX", pws_name: "Texas System")
      create(:public_water_system, stusps: "OK", pws_name: "Oklahoma System")

      get table_path, params: {state: "TX"}

      expect(response.body).to include("Texas System")
      expect(response.body).not_to include("Oklahoma System")
    end

    it "filters by owner_type array" do
      create(:public_water_system, owner_type: "Federal", pws_name: "Federal System")
      create(:public_water_system, owner_type: "State", pws_name: "State System")
      get table_path, params: {owner_type: ["Federal"]}
      expect(response.body).to include("Federal System")
      expect(response.body).not_to include("State System")
    end

    it "searches by pws_name" do
      create(:public_water_system, pws_name: "Aloha Water District")
      create(:public_water_system, pws_name: "Blue River Authority")
      get table_path, params: {search: "aloha"}
      expect(response.body).to include("Aloha Water District")
      expect(response.body).not_to include("Blue River Authority")
    end

    it "sorts null values last when sorting ascending" do
      create(:public_water_system, pws_name: "Null System", area_sq_miles: nil)
      create(:public_water_system, pws_name: "Data System", area_sq_miles: 10.0)
      get table_path, params: {sort: "area_sq_miles", direction: "asc"}
      expect(response.body.index("Data System")).to be < response.body.index("Null System")
    end

    it "sorts null values last when sorting descending" do
      create(:public_water_system, pws_name: "Null System", area_sq_miles: nil)
      create(:public_water_system, pws_name: "Data System", area_sq_miles: 10.0)
      get table_path, params: {sort: "area_sq_miles", direction: "desc"}
      expect(response.body.index("Data System")).to be < response.body.index("Null System")
    end

    it "renders Yes for true boolean columns" do
      create(:public_water_system, pws_name: "Test System", is_wholesaler: true)
      get table_path
      expect(response.body).to include("Yes")
    end

    it "renders No for false boolean columns" do
      create(:public_water_system, pws_name: "Test System", is_wholesaler: false, is_school_or_daycare: false)
      get table_path
      expect(response.body).to include("No")
    end

    it "renders '—' for nil boolean columns" do
      create(:public_water_system, pws_name: "Test System", is_wholesaler: nil, is_school_or_daycare: nil, open_health_viol: nil)
      get table_path
      expect(response.body).not_to match(/<td[^>]*>\s*No\s*<\/td>/)
      expect(response.body).to include("—")
    end

    it "renders '—' for nil string columns" do
      create(:public_water_system, pws_name: "Test System", source_water_protection_code: nil)
      get table_path
      expect(response.body).to include("—")
    end

    it "renders stacked ▲▼ sort icons on column headers" do
      get table_path
      expect(response.body).to include("▲")
      expect(response.body).to include("▼")
    end

    it "highlights the up arrow (text-gray-600) on the active column when sorted asc" do
      get table_path, params: {sort: "pws_name", direction: "asc"}
      expect(response.body).to include("text-gray-600")
    end

    it "highlights the down arrow (text-gray-600) on the active column when sorted desc" do
      get table_path, params: {sort: "pws_name", direction: "desc"}
      expect(response.body).to include("text-gray-600")
    end
  end
end
