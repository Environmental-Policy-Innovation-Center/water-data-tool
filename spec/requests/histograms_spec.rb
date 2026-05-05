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
        %w[paperwork_violations_5yr paperwork_violations_10yr].each do |field|
          get histogram_path, params: {field: field}

          expect(response).to have_http_status(:ok), "Expected 200 for field=#{field}"
        end
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
