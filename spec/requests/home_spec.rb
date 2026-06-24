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

    it "returns 200 when encoded= param is present" do
      get root_path, params: {encoded: encode_state({"cols" => "stusps"})}
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a malformed encoded= value" do
      get root_path, params: {encoded: "!!!invalid!!!"}
      expect(response).to have_http_status(:ok)
    end
  end

  # Filter menus are server-rendered from the decoded `encoded=` blob so a shared URL
  # shows its active filters on load. See docs/open_items/FILTER_SERVER_RENDER.md.
  describe "GET / filter menu server-render" do
    # Assert against the parsed DOM rather than raw-string regex: several controls carry
    # data-action="...->..." whose literal `>` breaks naive `[^>]*` tag matching.
    def dom = Nokogiri::HTML(response.body)
    def checked?(id) = dom.at_css("##{id}")&.attr("checked").present?
    def label_text(id) = dom.at_css("##{id}")&.text

    context "radio filters" do
      it "checks the default radio when the param is absent" do
        get root_path
        expect(checked?("ws-both")).to be(true)
        expect(checked?("ws-ground")).to be(false)
      end

      it "restores gw_sw_code (Groundwater) to the matching radio" do
        get root_path, params: {encoded: encode_state({"filters" => {"gw_sw_code" => "Groundwater"}})}
        expect(checked?("ws-ground")).to be(true)
        expect(checked?("ws-both")).to be(false)
        expect(checked?("ws-surface")).to be(false)
      end

      it "restores gw_sw_code (Surface Water) to the matching radio" do
        get root_path, params: {encoded: encode_state({"filters" => {"gw_sw_code" => "Surface Water"}})}
        expect(checked?("ws-surface")).to be(true)
        expect(checked?("ws-both")).to be(false)
      end

      it "restores symbology_field (Modeled) to the matching boundary-type radio" do
        get root_path, params: {encoded: encode_state({"filters" => {"symbology_field" => "Modeled"}})}
        expect(checked?("bt-modeled")).to be(true)
        expect(checked?("bt-both")).to be(false)
      end
    end

    context "bool checkboxes" do
      it "leaves bool checkboxes unchecked when their param is absent" do
        get root_path
        expect(checked?("has-source-water-protection")).to be(false)
        expect(checked?("compliance-open-violations")).to be(false)
      end

      it "checks has_source_protection when set" do
        get root_path, params: {encoded: encode_state({"filters" => {"has_source_protection" => "true"}})}
        expect(checked?("has-source-water-protection")).to be(true)
      end

      it "checks is_wholesaler when set" do
        get root_path, params: {encoded: encode_state({"filters" => {"is_wholesaler" => "true"}})}
        expect(checked?("is-wholesaler")).to be(true)
      end

      it "checks has_open_violations when set" do
        get root_path, params: {encoded: encode_state({"filters" => {"has_open_violations" => "true"}})}
        expect(checked?("compliance-open-violations")).to be(true)
      end
    end

    context "multi-select groups" do
      it "checks all owner_type options and the select-all when the param is absent" do
        get root_path
        expect(checked?("type-federal-government")).to be(true)
        expect(checked?("type-public-private")).to be(true)
        expect(checked?("type-deselect-all")).to be(true)
        expect(label_text("type-deselect-all-txt")).to eq("Deselect all")
      end

      it "restores only the selected owner_type options (partial selection)" do
        get root_path, params: {encoded: encode_state({"filters" => {"owner_type" => ["Federal", "Native American"]}})}
        expect(checked?("type-federal-government")).to be(true)
        expect(checked?("type-native-american")).to be(true)
        expect(checked?("type-state-government")).to be(false)
        expect(checked?("type-private")).to be(false)
      end

      it "unchecks the select-all and relabels it when the owner_type selection is partial" do
        get root_path, params: {encoded: encode_state({"filters" => {"owner_type" => ["Federal"]}})}
        expect(checked?("type-deselect-all")).to be(false)
        expect(label_text("type-deselect-all-txt")).to eq("Select all")
      end

      it "restores only the selected primacy_type options" do
        get root_path, params: {encoded: encode_state({"filters" => {"primacy_type" => ["State"]}})}
        expect(checked?("primacy-type-state")).to be(true)
        expect(checked?("primacy-type-tribal")).to be(false)
        expect(checked?("primacy-type-territory")).to be(false)
      end
    end
  end

  describe "GET /map with encoded= param" do
    it "applies filters encoded in encoded=" do
      gw = create(:public_water_system, gw_sw_code: "Groundwater")
      sw = create(:public_water_system, gw_sw_code: "Surface Water")

      get map_path, params: {encoded: encode_state({"filters" => {"gw_sw_code" => "Groundwater"}})}

      json = response.parsed_body
      expect(json["pwsids"]).to include(gw.pwsid)
      expect(json["pwsids"]).not_to include(sw.pwsid)
    end

    it "returns empty state gracefully for a malformed encoded= value" do
      create(:public_water_system)

      get map_path, params: {encoded: "!!!invalid!!!"}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["pwsids"]).to be_an(Array)
    end
  end

  describe "GET /table with encoded= param" do
    it "applies filters encoded in encoded=" do
      create(:public_water_system, gw_sw_code: "GW", pws_name: "Groundwater System")
      create(:public_water_system, gw_sw_code: "SW", pws_name: "Surface System")

      get table_path, params: {encoded: encode_state({"filters" => {"gw_sw_code" => "GW"}})}

      expect(response.body).to include("Groundwater System")
      expect(response.body).not_to include("Surface System")
    end

    it "applies cols encoded in encoded=" do
      get table_path, params: {encoded: encode_state({"cols" => "stusps"})}

      expect(response.body).to include("State")
      expect(response.body).not_to include("County")
    end

    it "returns 200 for a malformed encoded= value" do
      get table_path, params: {encoded: "!!!invalid!!!"}
      expect(response).to have_http_status(:ok)
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

      get map_path, params: {encoded: encode_state({"filters" => {"gw_sw_code" => "Groundwater"}})}

      json = response.parsed_body
      expect(json["pwsids"]).to include(gw.pwsid)
      expect(json["pwsids"]).not_to include(sw.pwsid)
    end

    it "returns an empty array when no systems match the filters" do
      create(:public_water_system, gw_sw_code: "Groundwater")

      get map_path, params: {encoded: encode_state({"filters" => {"gw_sw_code" => "Surface Water"}})}

      expect(response.parsed_body["pwsids"]).to eq([])
    end

    it "filters by health subcat range params through the controller" do
      match = create(:public_water_system)
      excluded = create(:public_water_system)
      create(:violations_summary, pwsid: match.pwsid, groundwater_rule_5yr: 5)
      create(:violations_summary, pwsid: excluded.pwsid, groundwater_rule_5yr: 1)

      get map_path, params: {encoded: encode_state({"filters" => {"groundwater_rule_5yr_min" => 4, "groundwater_rule_5yr_max" => 10}})}

      json = response.parsed_body
      expect(json["pwsids"]).to include(match.pwsid)
      expect(json["pwsids"]).not_to include(excluded.pwsid)
    end

    it "filters by paperwork violations range params through the controller" do
      match = create(:public_water_system)
      excluded = create(:public_water_system)
      create(:violations_summary, pwsid: match.pwsid, paperwork_violations_5yr: 10)
      create(:violations_summary, pwsid: excluded.pwsid, paperwork_violations_5yr: 1)

      get map_path, params: {encoded: encode_state({"filters" => {"paperwork_violations_5yr_min" => 5, "paperwork_violations_5yr_max" => 20}})}

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
      expect(response.body).to include("Grant eligible")
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
      get table_path, params: {encoded: encode_state({"filters" => {"gw_sw_code" => "GW"}})}
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
      get table_path, params: {encoded: encode_state({"filters" => {"owner_type" => ["Federal"]}})}
      expect(response.body).to include("Federal System")
      expect(response.body).not_to include("State System")
    end

    it "searches by pws_name via encoded state" do
      create(:public_water_system, pws_name: "Aloha Water District")
      create(:public_water_system, pws_name: "Blue River Authority")
      get table_path, params: {encoded: encode_state({"search" => "aloha"})}
      expect(response.body).to include("Aloha Water District")
      expect(response.body).not_to include("Blue River Authority")
    end

    it "searches by pwsid via encoded state" do
      create(:public_water_system, pws_name: "Aloha Water District", pwsid: "TX0010001")
      create(:public_water_system, pws_name: "Blue River Authority", pwsid: "OR0020002")
      get table_path, params: {encoded: encode_state({"search" => "TX001"})}
      expect(response.body).to include("Aloha Water District")
      expect(response.body).not_to include("Blue River Authority")
    end

    it "includes the search term in the sr-only caption" do
      create(:public_water_system, pws_name: "Aloha Water District")
      get table_path, params: {encoded: encode_state({"search" => "aloha"})}
      expect(response.body).to include("filtered by search: aloha")
    end

    it "omits the search phrase from the sr-only caption when no search is active" do
      create(:public_water_system, pws_name: "Aloha Water District")
      get table_path
      expect(response.body).not_to include("filtered by search:")
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

    context "sorting by violations_summaries columns" do
      it "sorts by health_violations_5yr ascending" do
        low = create(:public_water_system, pws_name: "Low Viols")
        high = create(:public_water_system, pws_name: "High Viols")
        create(:violations_summary, pwsid: low.pwsid, health_violations_5yr: 1)
        create(:violations_summary, pwsid: high.pwsid, health_violations_5yr: 9)

        get table_path, params: {sort: "health_violations_5yr", direction: "asc"}

        expect(response.body.index("Low Viols")).to be < response.body.index("High Viols")
      end

      it "sorts by health_violations_5yr descending" do
        low = create(:public_water_system, pws_name: "Low Viols")
        high = create(:public_water_system, pws_name: "High Viols")
        create(:violations_summary, pwsid: low.pwsid, health_violations_5yr: 1)
        create(:violations_summary, pwsid: high.pwsid, health_violations_5yr: 9)

        get table_path, params: {sort: "health_violations_5yr", direction: "desc"}

        expect(response.body.index("High Viols")).to be < response.body.index("Low Viols")
      end

      it "sorts systems with no violations_summary last (null values last)" do
        with_data = create(:public_water_system, pws_name: "Has Data")
        create(:public_water_system, pws_name: "No Data")
        create(:violations_summary, pwsid: with_data.pwsid, health_violations_5yr: 5)

        get table_path, params: {sort: "health_violations_5yr", direction: "asc"}

        expect(response.body.index("Has Data")).to be < response.body.index("No Data")
      end

      it "sorts by paperwork_violations_10yr" do
        low = create(:public_water_system, pws_name: "Few Paperwork")
        high = create(:public_water_system, pws_name: "Many Paperwork")
        create(:violations_summary, pwsid: low.pwsid, paperwork_violations_10yr: 2)
        create(:violations_summary, pwsid: high.pwsid, paperwork_violations_10yr: 20)

        get table_path, params: {sort: "paperwork_violations_10yr", direction: "asc"}

        expect(response.body.index("Few Paperwork")).to be < response.body.index("Many Paperwork")
      end
    end

    context "sorting by boil_water_summaries columns" do
      it "sorts by total_notices ascending" do
        few = create(:public_water_system, pws_name: "Few Notices")
        many = create(:public_water_system, pws_name: "Many Notices")
        create(:boil_water_summary, pwsid: few.pwsid, total_notices: 1)
        create(:boil_water_summary, pwsid: many.pwsid, total_notices: 10)

        get table_path, params: {sort: "total_notices", direction: "asc"}

        expect(response.body.index("Few Notices")).to be < response.body.index("Many Notices")
      end

      it "sorts systems with no boil_water_summary last (null values last)" do
        with_data = create(:public_water_system, pws_name: "Has Notices")
        create(:public_water_system, pws_name: "No Notices")
        create(:boil_water_summary, pwsid: with_data.pwsid, total_notices: 3)

        get table_path, params: {sort: "total_notices", direction: "asc"}

        expect(response.body.index("Has Notices")).to be < response.body.index("No Notices")
      end
    end

    context "sorting by demographics columns" do
      it "sorts by total_population ascending" do
        small = create(:public_water_system, pws_name: "Small Pop")
        large = create(:public_water_system, pws_name: "Large Pop")
        create(:demographic, pwsid: small.pwsid, total_population: 100)
        create(:demographic, pwsid: large.pwsid, total_population: 99_999)

        get table_path, params: {sort: "total_population", direction: "asc"}

        expect(response.body.index("Small Pop")).to be < response.body.index("Large Pop")
      end

      it "sorts by median_household_income descending" do
        low = create(:public_water_system, pws_name: "Low Income")
        high = create(:public_water_system, pws_name: "High Income")
        create(:demographic, pwsid: low.pwsid, median_household_income: 30_000)
        create(:demographic, pwsid: high.pwsid, median_household_income: 120_000)

        get table_path, params: {sort: "median_household_income", direction: "desc"}

        expect(response.body.index("High Income")).to be < response.body.index("Low Income")
      end

      it "sorts systems with no demographic last (null values last)" do
        with_data = create(:public_water_system, pws_name: "Has Demo")
        create(:public_water_system, pws_name: "No Demo")
        create(:demographic, pwsid: with_data.pwsid, total_population: 500)

        get table_path, params: {sort: "total_population", direction: "asc"}

        expect(response.body.index("Has Demo")).to be < response.body.index("No Demo")
      end
    end

    context "sorting by environmental_justices columns" do
      it "sorts by cejst_disadvantaged_pct ascending" do
        low = create(:public_water_system, pws_name: "Low Disadvantaged")
        high = create(:public_water_system, pws_name: "High Disadvantaged")
        create(:environmental_justice, pwsid: low.pwsid, cejst_disadvantaged_pct: 10)
        create(:environmental_justice, pwsid: high.pwsid, cejst_disadvantaged_pct: 90)

        get table_path, params: {sort: "cejst_disadvantaged_pct", direction: "asc"}

        expect(response.body.index("Low Disadvantaged")).to be < response.body.index("High Disadvantaged")
      end
    end

    context "sorting by funding_summaries columns" do
      it "sorts by times_funded ascending" do
        less = create(:public_water_system, pws_name: "Less Funded")
        more = create(:public_water_system, pws_name: "More Funded")
        create(:funding_summary, pwsid: less.pwsid, times_funded: 1)
        create(:funding_summary, pwsid: more.pwsid, times_funded: 5)

        get table_path, params: {sort: "times_funded", direction: "asc"}

        expect(response.body.index("Less Funded")).to be < response.body.index("More Funded")
      end
    end

    context "sorting by watershed_hazards columns" do
      it "sorts by num_facilities ascending" do
        few = create(:public_water_system, pws_name: "Few Facilities")
        many = create(:public_water_system, pws_name: "Many Facilities")
        create(:watershed_hazard, pwsid: few.pwsid, num_facilities: 2)
        create(:watershed_hazard, pwsid: many.pwsid, num_facilities: 50)

        get table_path, params: {sort: "num_facilities", direction: "asc"}

        expect(response.body.index("Few Facilities")).to be < response.body.index("Many Facilities")
      end
    end

    context "sorting by trend_data columns" do
      it "sorts by population_pct_change_capped ascending" do
        shrinking = create(:public_water_system, pws_name: "Shrinking System")
        growing = create(:public_water_system, pws_name: "Growing System")
        create(:trend_datum, pwsid: shrinking.pwsid, population_pct_change_capped: -5.0)
        create(:trend_datum, pwsid: growing.pwsid, population_pct_change_capped: 10.0)

        get table_path, params: {sort: "population_pct_change_capped", direction: "asc"}

        expect(response).to have_http_status(:ok)
        expect(response.body.index("Shrinking System")).to be < response.body.index("Growing System")
      end

      it "sorts by mhi_pct_change_capped descending" do
        low = create(:public_water_system, pws_name: "Low Income Growth")
        high = create(:public_water_system, pws_name: "High Income Growth")
        create(:trend_datum, pwsid: low.pwsid, mhi_pct_change_capped: 2.0)
        create(:trend_datum, pwsid: high.pwsid, mhi_pct_change_capped: 25.0)

        get table_path, params: {sort: "mhi_pct_change_capped", direction: "desc"}

        expect(response).to have_http_status(:ok)
        expect(response.body.index("High Income Growth")).to be < response.body.index("Low Income Growth")
      end

      it "sorts systems with no trend_datum last (null values last)" do
        with_data = create(:public_water_system, pws_name: "Has Trend")
        create(:public_water_system, pws_name: "No Trend")
        create(:trend_datum, pwsid: with_data.pwsid, population_pct_change_capped: 5.0)

        get table_path, params: {sort: "population_pct_change_capped", direction: "asc"}

        expect(response).to have_http_status(:ok)
        expect(response.body.index("Has Trend")).to be < response.body.index("No Trend")
      end
    end

    it "filters by has_open_violations" do
      create(:public_water_system, pws_name: "Open Violation System", open_health_viol: true)
      create(:public_water_system, pws_name: "Clean System", open_health_viol: false)
      get table_path, params: {encoded: encode_state({"filters" => {"has_open_violations" => "true"}})}
      expect(response.body).to include("Open Violation System")
      expect(response.body).not_to include("Clean System")
    end

    it "renders Yes for true boolean columns" do
      create(:public_water_system, pws_name: "Test System", is_wholesaler: true, open_health_viol: true)
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

    context "with cols encoded in url state blob (column visibility)" do
      it "shows all columns when cols is absent from blob" do
        get table_path
        expect(response.body).to include("State")
        expect(response.body).to include("County")
        expect(response.body).to include("Grant eligible")
      end

      it "shows only the requested columns plus always-visible ones" do
        get table_path, params: {encoded: encode_state({cols: "stusps"})}
        expect(response.body).to include("State")
        expect(response.body).not_to include("County")
      end

      it "always shows the pws_name column regardless of cols" do
        get table_path, params: {encoded: encode_state({cols: "stusps"})}
        expect(response.body).to include("Utility Name")
      end

      it "ignores unknown column keys in cols" do
        get table_path, params: {encoded: encode_state({cols: "stusps,nonexistent_column"})}
        expect(response.body).to include("State")
        expect(response.body).not_to include("County")
      end

      it "shows multiple requested columns" do
        get table_path, params: {encoded: encode_state({cols: "stusps,counties"})}
        expect(response.body).to include("State")
        expect(response.body).to include("County")
        expect(response.body).not_to include("Grant eligible")
      end

      it "renders visible columns in cols order" do
        get table_path, params: {encoded: encode_state({cols: "counties,stusps"})}
        county_pos = response.body.index(">County</span>")
        state_pos = response.body.index(">State</span>")
        expect(county_pos).to be_present
        expect(state_pos).to be_present
        expect(county_pos).to be < state_pos
      end

      it "renders all columns in the manage-columns panel even when cols excludes some" do
        get root_path, params: {encoded: encode_state({cols: "counties,stusps"})}
        expect(response.body).to include("col_counties")
        expect(response.body).to include("col_stusps")
        expect(response.body).to include("col_pwsid")
      end
    end

    context "with - prefix col keys (full panel state format)" do
      it "shows only visible columns in the table (strips hidden - prefix cols)" do
        get table_path, params: {encoded: encode_state({cols: "stusps,-pwsid"})}
        expect(response.body).to include("State")
        expect(response.body).not_to include(">PWSID</")
      end

      it "renders panel with hidden column present but unchecked" do
        get root_path, params: {encoded: encode_state({cols: "stusps,-pwsid"})}
        body = response.body
        expect(body).to include("col_stusps")
        expect(body).to include("col_pwsid")
      end

      it "renders panel in blob col order with hidden columns in position" do
        get root_path, params: {encoded: encode_state({cols: "counties,-pwsid,stusps"})}
        counties_pos = response.body.index("col_counties")
        pwsid_pos = response.body.index("col_pwsid")
        stusps_pos = response.body.index("col_stusps")
        expect(counties_pos).to be < pwsid_pos
        expect(pwsid_pos).to be < stusps_pos
      end

      it "renders visible columns in table in blob col order" do
        get table_path, params: {encoded: encode_state({cols: "counties,-pwsid,stusps"})}
        county_pos = response.body.index(">County</span>")
        state_pos = response.body.index(">State</span>")
        expect(county_pos).to be < state_pos
      end
    end
  end
end
