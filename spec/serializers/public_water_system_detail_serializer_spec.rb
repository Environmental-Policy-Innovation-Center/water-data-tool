require "rails_helper"

RSpec.describe PublicWaterSystemDetailSerializer do
  subject(:result) { described_class.new(pws).serialize }

  describe "#serialize" do
    context "with all associations present" do
      let(:pws) { create(:public_water_system) }

      before do
        create(:demographic, public_water_system: pws)
        create(:violations_summary, public_water_system: pws)
        create(:environmental_justice, public_water_system: pws)
        create(:funding_summary, public_water_system: pws)
        create(:watershed_hazard, public_water_system: pws)
        create(:boil_water_summary, public_water_system: pws)
        create(:trend_datum, public_water_system: pws)
        pws.reload
      end

      it "returns a hash" do
        expect(result).to be_a(Hash)
      end

      it "includes all top-level PWS fields" do
        expect(result[:pwsid]).to eq(pws.pwsid)
        expect(result[:pws_name]).to eq(pws.pws_name)
        expect(result[:stusps]).to eq(pws.stusps)
        expect(result[:counties]).to eq(pws.counties)
      end

      it "does not include internal Rails fields" do
        expect(result).not_to have_key(:created_at)
        expect(result).not_to have_key(:updated_at)
      end

      describe "demographic association" do
        it "is present" do
          expect(result[:demographic]).to be_a(Hash)
        end

        it "includes expected fields" do
          demo = result[:demographic]
          expect(demo[:total_population]).to eq(pws.demographic.total_population)
          expect(demo[:median_household_income]).to eq(pws.demographic.median_household_income)
          expect(demo[:poverty_rate]).to eq(pws.demographic.poverty_rate)
          expect(demo[:unemployment_rate]).to eq(pws.demographic.unemployment_rate)
          expect(demo[:poc_rate]).to eq(pws.demographic.poc_rate)
          expect(demo[:most_common_rate_tier]).to eq(pws.demographic.most_common_rate_tier)
        end

        it "includes all water rate tier fields" do
          demo = result[:demographic]
          expect(demo).to have_key(:water_rate_under_125)
          expect(demo).to have_key(:water_rate_125_249)
          expect(demo).to have_key(:water_rate_250_499)
          expect(demo).to have_key(:water_rate_500_749)
          expect(demo).to have_key(:water_rate_750_999)
          expect(demo).to have_key(:water_rate_over_1000)
        end

        it "does not include pwsid or internal Rails fields" do
          demo = result[:demographic]
          expect(demo).not_to have_key(:pwsid)
          expect(demo).not_to have_key(:id)
          expect(demo).not_to have_key(:created_at)
          expect(demo).not_to have_key(:updated_at)
        end
      end

      describe "violations_summary association" do
        it "is present" do
          expect(result[:violations_summary]).to be_a(Hash)
        end

        it "includes 5yr and 10yr violation counts" do
          vs = result[:violations_summary]
          expect(vs[:health_violations_5yr]).to eq(pws.violations_summary.health_violations_5yr)
          expect(vs[:health_violations_10yr]).to eq(pws.violations_summary.health_violations_10yr)
          expect(vs[:violations_all_years]).to eq(pws.violations_summary.violations_all_years)
          expect(vs[:lead_and_copper_5yr]).to eq(pws.violations_summary.lead_and_copper_5yr)
          expect(vs[:paperwork_violations_10yr]).to eq(pws.violations_summary.paperwork_violations_10yr)
        end

        it "does not include internal Rails fields" do
          vs = result[:violations_summary]
          expect(vs).not_to have_key(:id)
          expect(vs).not_to have_key(:pwsid)
          expect(vs).not_to have_key(:created_at)
          expect(vs).not_to have_key(:updated_at)
        end
      end

      describe "environmental_justice association" do
        it "is present" do
          expect(result[:environmental_justice]).to be_a(Hash)
        end

        it "includes CEJST, SVI, EJScreen, and CVI fields" do
          ej = result[:environmental_justice]
          expect(ej[:cejst_disadvantaged_pct]).to eq(pws.environmental_justice.cejst_disadvantaged_pct)
          expect(ej[:svi_overall_pctl]).to eq(pws.environmental_justice.svi_overall_pctl)
          expect(ej[:ejscreen_drinking_water]).to eq(pws.environmental_justice.ejscreen_drinking_water)
          expect(ej[:cvi_overall_score]).to eq(pws.environmental_justice.cvi_overall_score)
        end
      end

      describe "funding_summary association" do
        it "is present" do
          expect(result[:funding_summary]).to be_a(Hash)
        end

        it "includes funding fields" do
          fs = result[:funding_summary]
          expect(fs[:times_funded]).to eq(pws.funding_summary.times_funded)
          expect(fs[:total_srf_assistance]).to eq(pws.funding_summary.total_srf_assistance)
          expect(fs[:total_principal_forgiveness]).to eq(pws.funding_summary.total_principal_forgiveness)
          expect(fs[:median_srf_assistance]).to eq(pws.funding_summary.median_srf_assistance)
        end
      end

      describe "watershed_hazard association" do
        it "is present" do
          expect(result[:watershed_hazard]).to be_a(Hash)
        end

        it "includes all hazard fields" do
          wh = result[:watershed_hazard]
          expect(wh[:num_facilities]).to eq(pws.watershed_hazard.num_facilities)
          expect(wh[:npdes_permits]).to eq(pws.watershed_hazard.npdes_permits)
          expect(wh[:permit_effluent_violations]).to eq(pws.watershed_hazard.permit_effluent_violations)
          expect(wh[:open_underground_storage_tanks]).to eq(pws.watershed_hazard.open_underground_storage_tanks)
          expect(wh[:risk_management_plan_facilities]).to eq(pws.watershed_hazard.risk_management_plan_facilities)
          expect(wh[:impaired_streams_303d]).to eq(pws.watershed_hazard.impaired_streams_303d)
        end
      end

      describe "boil_water_summary association" do
        it "is present" do
          expect(result[:boil_water_summary]).to be_a(Hash)
        end

        it "includes boil water fields" do
          bws = result[:boil_water_summary]
          expect(bws[:total_notices]).to eq(pws.boil_water_summary.total_notices)
          expect(bws[:first_advisory_date]).to eq(pws.boil_water_summary.first_advisory_date)
          expect(bws[:last_advisory_date]).to eq(pws.boil_water_summary.last_advisory_date)
          expect(bws[:date_range_display]).to eq(pws.boil_water_summary.date_range_display)
          expect(bws[:tooltip_text]).to eq(pws.boil_water_summary.tooltip_text)
        end
      end

      describe "trend_datum association" do
        it "is present" do
          expect(result[:trend_datum]).to be_a(Hash)
        end

        it "includes trend fields" do
          td = result[:trend_datum]
          expect(td[:population_pct_change]).to eq(pws.trend_datum.population_pct_change)
          expect(td[:population_pct_change_capped]).to eq(pws.trend_datum.population_pct_change_capped)
          expect(td[:population_change_flag]).to eq(pws.trend_datum.population_change_flag)
          expect(td[:mhi_pct_change]).to eq(pws.trend_datum.mhi_pct_change)
          expect(td[:mhi_pct_change_capped]).to eq(pws.trend_datum.mhi_pct_change_capped)
          expect(td[:income_change_flag]).to eq(pws.trend_datum.income_change_flag)
        end
      end
    end

    # All has_one associations can be nil when ETL has not yet populated data
    # for a given system. Serializers must return null rather than raise NoMethodError.
    context "when associations are nil (ETL not yet run for this system)" do
      let(:pws) { create(:public_water_system) }

      it "returns nil for demographic" do
        expect(result[:demographic]).to be_nil
      end

      it "returns nil for violations_summary" do
        expect(result[:violations_summary]).to be_nil
      end

      it "returns nil for environmental_justice" do
        expect(result[:environmental_justice]).to be_nil
      end

      it "returns nil for funding_summary" do
        expect(result[:funding_summary]).to be_nil
      end

      it "returns nil for watershed_hazard" do
        expect(result[:watershed_hazard]).to be_nil
      end

      it "returns nil for boil_water_summary" do
        expect(result[:boil_water_summary]).to be_nil
      end

      it "returns nil for trend_datum" do
        expect(result[:trend_datum]).to be_nil
      end

      it "still returns all top-level PWS fields" do
        expect(result[:pwsid]).to eq(pws.pwsid)
        expect(result[:pws_name]).to eq(pws.pws_name)
        expect(result[:stusps]).to eq(pws.stusps)
      end
    end

    context "when only some associations are present" do
      let(:pws) { create(:public_water_system) }

      before do
        create(:demographic, public_water_system: pws)
        pws.reload
      end

      it "returns the present association and nil for the rest" do
        expect(result[:demographic]).to be_a(Hash)
        expect(result[:violations_summary]).to be_nil
        expect(result[:funding_summary]).to be_nil
      end
    end
  end
end
