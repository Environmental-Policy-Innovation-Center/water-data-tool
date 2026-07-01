require "rails_helper"

RSpec.describe FilterParams do
  def permitted(raw_params)
    ActionController::Parameters.new(raw_params).then { |p| FilterParams.permit(p) }
  end

  it "permits scalar categorical params" do
    result = permitted(gw_sw_code: "Groundwater", state: "VT", unknown_param: "sneaky")
    expect(result[:gw_sw_code]).to eq("Groundwater")
    expect(result[:state]).to eq("VT")
    expect(result[:unknown_param]).to be_nil
  end

  it "strips unpermitted params" do
    result = permitted(admin: true, drop_table: "users")
    expect(result.to_h).to be_empty
  end

  it "permits array params" do
    result = permitted(owner_type: %w[Federal Local], primacy_type: ["State"], pop_cat_5: ["<=500"])
    expect(result[:owner_type]).to eq(%w[Federal Local])
    expect(result[:primacy_type]).to eq(["State"])
    expect(result[:pop_cat_5]).to eq(["<=500"])
  end

  it "permits health sub-category range params" do
    result = permitted(groundwater_rule_5yr_min: "2", lead_and_copper_10yr_max: "10")
    expect(result[:groundwater_rule_5yr_min]).to eq("2")
    expect(result[:lead_and_copper_10yr_max]).to eq("10")
  end

  it "permits paperwork violation range params" do
    result = permitted(paperwork_violations_5yr_min: "1", paperwork_violations_10yr_max: "5")
    expect(result[:paperwork_violations_5yr_min]).to eq("1")
    expect(result[:paperwork_violations_10yr_max]).to eq("5")
  end

  it "permits demographic range params" do
    result = permitted(poverty_rate_min: "10", median_household_income_max: "50000")
    expect(result[:poverty_rate_min]).to eq("10")
    expect(result[:median_household_income_max]).to eq("50000")
  end

  it "permits environmental justice range params" do
    result = permitted(cejst_disadvantaged_pct_min: "25", svi_overall_pctl_max: "80")
    expect(result[:cejst_disadvantaged_pct_min]).to eq("25")
    expect(result[:svi_overall_pctl_max]).to eq("80")
  end

  it "permits funding range params" do
    result = permitted(total_srf_assistance_min: "100000", times_funded_max: "3")
    expect(result[:total_srf_assistance_min]).to eq("100000")
    expect(result[:times_funded_max]).to eq("3")
  end

  it "permits watershed hazard range params" do
    result = permitted(num_facilities_min: "5", impaired_streams_303d_max: "10")
    expect(result[:num_facilities_min]).to eq("5")
    expect(result[:impaired_streams_303d_max]).to eq("10")
  end

  it "permits trend range params (capped columns)" do
    result = permitted(population_pct_change_capped_min: "-5", mhi_pct_change_capped_max: "20")
    expect(result[:population_pct_change_capped_min]).to eq("-5")
    expect(result[:mhi_pct_change_capped_max]).to eq("20")
  end

  it "permits geographic params" do
    result = permitted(county_geoid: "08031", bounds: "-105,39,-104,40")
    expect(result[:county_geoid]).to eq("08031")
    expect(result[:bounds]).to eq("-105,39,-104,40")
  end
end
