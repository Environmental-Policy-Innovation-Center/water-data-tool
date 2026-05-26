require "rails_helper"

RSpec.describe "Histograms", type: :request do
  describe "GET /public_water_systems/histogram" do
    context "with a valid field" do
      it "returns 200 with bins, domain_min, and domain_max" do
        pws = create(:public_water_system)
        create(:violations_summary, pwsid: pws.pwsid, paperwork_violations_5yr: 5)

        get histogram_path, params: {field: "paperwork_violations_5yr"}

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["bins"]).to be_an(Array)
        expect(json).to have_key("domain_min")
        expect(json).to have_key("domain_max")
      end

      it "returns 200 for all allowed fields" do
        PublicWaterSystems::HistogramsController::ALLOWED_FIELDS.each do |field|
          get histogram_path, params: {field: field}

          expect(response).to have_http_status(:ok), "Expected 200 for field=#{field}"
        end
      end

      it "routes demographic fields to Demographic model" do
        pws = create(:public_water_system)
        create(:demographic, public_water_system: pws, pwsid: pws.pwsid, poverty_rate: 25.0)

        get histogram_path, params: {field: "poverty_rate"}

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        # poverty_rate uses format: percent — fixed domain 0–100, 20 bins
        expect(json["domain_min"]).to eq(0)
        expect(json["domain_max"]).to eq(100)
        expect(json["bins"].count).to eq(20)
        expect(json["bins"].sum { |b| b["count"] }).to eq(1)
      end

      it "routes trend fields to TrendDatum model with percent_change format covering ±200%" do
        pws = create(:public_water_system)
        create(:trend_datum, public_water_system: pws, pwsid: pws.pwsid, population_pct_change_capped: -3.5)

        get histogram_path, params: {field: "population_pct_change_capped"}

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["domain_min"]).to eq(-200)
        expect(json["domain_max"]).to eq(200)
        expect(json["bins"].count).to eq(40)
      end
    end

    context "with an invalid field" do
      it "returns 400 for an unknown field name" do
        get histogram_path, params: {field: "unknown_column"}

        expect(response).to have_http_status(:bad_request)
      end

      it "returns 400 when field param is missing" do
        get histogram_path

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
