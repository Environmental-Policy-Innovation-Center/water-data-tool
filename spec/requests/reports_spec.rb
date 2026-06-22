require "rails_helper"

RSpec.describe "Reports", type: :request do
  describe "GET /public_water_systems/:pwsid/report" do
    let(:turbo_frame_headers) { {"Turbo-Frame" => "report-body"} }

    shared_examples "report content" do
      it "renders the system name and all section headings" do
        expect(response.body).to include("Clearwater Co")
        %w[Overview Demographics Violations Funding].each do |heading|
          expect(response.body).to include(heading)
        end
      end

      it "handles nil associations gracefully" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Data not available")
      end
    end

    shared_examples "report populated content" do
      it "renders populated association data when present" do
        expect(response.body).to include("75,000")
        expect(response.body).to include("3")
      end
    end

    context "as a full page" do
      it "returns 200 with a full HTML document and stylesheets" do
        pws = create(:public_water_system)

        get report_path(pwsid: pws.pwsid)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("<!DOCTYPE html>")
        expect(response.body).to include('rel="stylesheet"')
        expect(response.body).to include("tailwind")
        expect(response.body).to include('<turbo-frame id="report-body">')
        expect(response.body).to include('class="report-content"')
      end

      it "sets the page title from the utility name" do
        pws = create(:public_water_system, pws_name: "Clearwater Co")

        get report_path(pwsid: pws.pwsid)

        expect(response.body).to include("<title>Clearwater Co — Utility Report</title>")
      end

      it "renders print and back-to-map controls when not navigating from the map" do
        pws = create(:public_water_system)

        get report_path(pwsid: pws.pwsid)

        expect(response.body).to include('id="tt-print-report"')
        expect(response.body).to include('aria-label="Print report"')
        expect(response.body).to include('aria-label="Back to map"')
        expect(response.body).to include('href="/"')
        expect(response.body).to include('data-turbo="false"')
      end

      it "renders a close button when navigating from a same-host page" do
        pws = create(:public_water_system)

        get report_path(pwsid: pws.pwsid), headers: {"Referer" => root_url}

        expect(response.body).to include('id="tt-print-report"')
        expect(response.body).to include('aria-label="Close report"')
        expect(response.body).to include('data-action="click->report#back"')
      end

      context "with report body content" do
        let(:pws) { create(:public_water_system, pws_name: "Clearwater Co") }

        before { get report_path(pwsid: pws.pwsid) }

        include_examples "report content"
      end

      context "with populated associations" do
        let(:pws) { create(:public_water_system, pws_name: "Clearwater Co") }

        before do
          create(:demographic, pwsid: pws.pwsid, total_population: 75_000)
          create(:violations_summary, pwsid: pws.pwsid, health_violations_5yr: 3)
          get report_path(pwsid: pws.pwsid)
        end

        include_examples "report populated content"
      end

      describe "trend arrows" do
        it "shows ▲ for a positive percentage" do
          pws = create(:public_water_system)
          create(:trend_datum, pwsid: pws.pwsid, population_pct_change: 8.3)

          get report_path(pwsid: pws.pwsid)

          expect(response.body).to include("▲")
        end

        it "shows ▼ for a negative percentage" do
          pws = create(:public_water_system)
          create(:trend_datum, pwsid: pws.pwsid, population_pct_change: -4.1)

          get report_path(pwsid: pws.pwsid)

          expect(response.body).to include("▼")
        end

        it "shows no arrow when pct is nil" do
          pws = create(:public_water_system)
          create(:trend_datum, pwsid: pws.pwsid, population_pct_change: nil,
            mhi_pct_change: nil, households_pct_change: nil,
            poverty_pct_change: nil, unemployment_pct_change: nil, poc_pct_change: nil)

          get report_path(pwsid: pws.pwsid)

          expect(response.body).not_to include("▲")
          expect(response.body).not_to include("▼")
        end

        it "includes the 10-year period in the section title" do
          pws = create(:public_water_system)
          create(:trend_datum, pwsid: pws.pwsid)

          get report_path(pwsid: pws.pwsid)

          expect(response.body).to include("10-Year Trends")
        end
      end
    end

    context "as a turbo-frame request" do
      it "returns a fragment without the report layout" do
        pws = create(:public_water_system)

        get report_path(pwsid: pws.pwsid), headers: turbo_frame_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("<!DOCTYPE html>")
        expect(response.body).to include('<turbo-frame id="report-body">')
        expect(response.body).to include('class="report-content"')
        expect(response.body).not_to include('id="tt-print-report"')
      end

      context "with report body content" do
        let(:pws) { create(:public_water_system, pws_name: "Clearwater Co") }

        before { get report_path(pwsid: pws.pwsid), headers: turbo_frame_headers }

        include_examples "report content"
      end

      context "with populated associations" do
        let(:pws) { create(:public_water_system, pws_name: "Clearwater Co") }

        before do
          create(:demographic, pwsid: pws.pwsid, total_population: 75_000)
          create(:violations_summary, pwsid: pws.pwsid, health_violations_5yr: 3)
          get report_path(pwsid: pws.pwsid), headers: turbo_frame_headers
        end

        include_examples "report populated content"
      end
    end

    it "routes tribal systems with numeric EPA region prefix" do
      pws = create(:public_water_system, pwsid: "084690440")

      get report_path(pwsid: pws.pwsid)

      expect(response).to have_http_status(:ok)
    end

    it "routes Utah-style systems with letters in the system-number portion" do
      pws = create(:public_water_system, pwsid: "UTAH01001")

      get report_path(pwsid: pws.pwsid)

      expect(response).to have_http_status(:ok)
    end

    it "routes compound systems whose pwsid is multiple IDs joined by '; '" do
      pws = build(:public_water_system, pwsid: "ND3401128; ND1001380; ND4801479")
      pws.save!(validate: false)

      get "/public_water_systems/ND3401128;%20ND1001380;%20ND4801479/report"

      expect(response).to have_http_status(:ok)
    end

    it "routes compound systems when the pwsid is fully URI-encoded like the map popup link" do
      pws = build(:public_water_system, pwsid: "ND3401128; ND1001380; ND4801479")
      pws.save!(validate: false)

      encoded_pwsid = URI.encode_uri_component(pws.pwsid)
      get "/public_water_systems/#{encoded_pwsid}/report"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<!DOCTYPE html>")
      expect(response.body).to include("ND3401128")
    end

    it "returns 404 when the system does not exist" do
      get report_path(pwsid: "ZZ0000000")

      expect(response).to have_http_status(:not_found)
    end
  end
end
