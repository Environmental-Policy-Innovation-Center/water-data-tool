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
      expect(response.body.scan('class="grid-item"').count).to eq(27)
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

  describe "GET /table.json" do
    let(:ssp_params) { {draw: 1, start: 0, length: 100, "search[value]": "", "order[0][column]": 0, "order[0][dir]": "asc"} }

    it "returns 200" do
      get table_path(format: :json), params: ssp_params
      expect(response).to have_http_status(:ok)
    end

    it "returns JSON with DataTables SSP keys" do
      get table_path(format: :json), params: ssp_params
      body = response.parsed_body
      expect(body.keys).to include("draw", "recordsTotal", "recordsFiltered", "data")
    end

    it "echoes the draw parameter" do
      get table_path(format: :json), params: ssp_params.merge(draw: 7)
      expect(response.parsed_body["draw"]).to eq(7)
    end

    it "returns a row hash for each PWS" do
      create(:public_water_system, pws_name: "Aloha Water")
      get table_path(format: :json), params: ssp_params
      row = response.parsed_body["data"].first
      expect(row["pws_name"]).to eq("Aloha Water")
      expect(row).to have_key("pwsid")
      expect(row).to have_key("stusps")
      expect(row).to have_key("health_violations_5yr")
      expect(row).to have_key("total_population")
      expect(row).to have_key("cejst_disadvantaged_pct")
      expect(row).to have_key("total_srf_assistance")
      expect(row).to have_key("impaired_streams_303d")
    end

    it "reflects recordsTotal and recordsFiltered" do
      create_list(:public_water_system, 3)
      get table_path(format: :json), params: ssp_params
      body = response.parsed_body
      expect(body["recordsTotal"]).to eq(3)
      expect(body["recordsFiltered"]).to eq(3)
    end

    it "filters by search value (pws_name)" do
      create(:public_water_system, pws_name: "Aloha Water District")
      create(:public_water_system, pws_name: "Blue River Authority")
      get table_path(format: :json), params: ssp_params.merge("search[value]": "aloha")
      body = response.parsed_body
      expect(body["recordsFiltered"]).to eq(1)
      expect(body["data"].first["pws_name"]).to eq("Aloha Water District")
    end

    it "paginates via start and length" do
      create(:public_water_system, pws_name: "Alpha Water")
      create(:public_water_system, pws_name: "Zebra Water")
      get table_path(format: :json), params: ssp_params.merge(start: 1, length: 1)
      body = response.parsed_body
      expect(body["data"].length).to eq(1)
      expect(body["data"].first["pws_name"]).to eq("Zebra Water")
    end

    it "orders by pws_name desc when requested" do
      create(:public_water_system, pws_name: "Alpha Water")
      create(:public_water_system, pws_name: "Zebra Water")
      get table_path(format: :json), params: ssp_params.merge("order[0][dir]": "desc")
      names = response.parsed_body["data"].map { |r| r["pws_name"] }
      expect(names).to eq(["Zebra Water", "Alpha Water"])
    end

    it "falls back to pws_name ordering for an invalid column index" do
      create(:public_water_system, pws_name: "Alpha Water")
      create(:public_water_system, pws_name: "Zebra Water")
      get table_path(format: :json), params: ssp_params.merge("order[0][column]": 999)
      names = response.parsed_body["data"].map { |r| r["pws_name"] }
      expect(names).to eq(["Alpha Water", "Zebra Water"])
    end

    context "with filter params" do
      it "filters by gw_sw_code" do
        create(:public_water_system, gw_sw_code: "GW")
        create(:public_water_system, gw_sw_code: "SW")
        get table_path(format: :json), params: ssp_params.merge(gw_sw_code: "GW")
        expect(response.parsed_body["recordsFiltered"]).to eq(1)
      end

      it "filters by owner_type array" do
        create(:public_water_system, owner_type: "Federal")
        create(:public_water_system, owner_type: "State")
        get table_path(format: :json), params: ssp_params.merge(owner_type: ["Federal"])
        expect(response.parsed_body["recordsFiltered"]).to eq(1)
      end

      it "filters open violations" do
        create(:public_water_system, open_health_viol: "Yes")
        create(:public_water_system, open_health_viol: "No")
        get table_path(format: :json), params: ssp_params.merge(has_open_violations: "true")
        expect(response.parsed_body["recordsFiltered"]).to eq(1)
      end

      it "does not change recordsTotal when filters are applied" do
        create_list(:public_water_system, 3, gw_sw_code: "GW")
        create(:public_water_system, gw_sw_code: "SW")
        get table_path(format: :json), params: ssp_params.merge(gw_sw_code: "GW")
        body = response.parsed_body
        expect(body["recordsTotal"]).to eq(4)
        expect(body["recordsFiltered"]).to eq(3)
      end
    end
  end
end
