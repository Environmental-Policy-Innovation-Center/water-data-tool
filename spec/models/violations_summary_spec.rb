# == Schema Information
#
# Table name: violations_summaries
#
#  id                               :bigint           not null, primary key
#  groundwater_rule_10yr            :integer
#  groundwater_rule_5yr             :integer
#  health_violations_10yr           :integer
#  health_violations_5yr            :integer
#  inorganic_chemicals_10yr         :integer
#  inorganic_chemicals_5yr          :integer
#  lead_and_copper_10yr             :integer
#  lead_and_copper_5yr              :integer
#  paperwork_violations_10yr        :integer
#  paperwork_violations_5yr         :integer
#  pwsid                            :string           not null
#  radionuclides_10yr               :integer
#  radionuclides_5yr                :integer
#  stage_1_disinfectants_10yr       :integer
#  stage_1_disinfectants_5yr        :integer
#  stage_2_disinfectants_10yr       :integer
#  stage_2_disinfectants_5yr        :integer
#  surface_water_treatment_10yr     :integer
#  surface_water_treatment_5yr      :integer
#  synthetic_organic_chemicals_10yr :integer
#  synthetic_organic_chemicals_5yr  :integer
#  total_coliform_10yr              :integer
#  total_coliform_5yr               :integer
#  total_violations_10yr            :integer
#  total_violations_5yr             :integer
#  violations_all_years             :integer
#  volatile_organic_chemicals_10yr  :integer
#  volatile_organic_chemicals_5yr   :integer
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#
# Indexes
#
#  index_violations_summaries_on_pwsid  (pwsid) UNIQUE
#
require "rails_helper"

RSpec.describe ViolationsSummary, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:public_water_system).with_foreign_key("pwsid") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:pwsid) }
  end

  describe ".histogram_bins" do
    it "returns bin structure with min, max, and count" do
      pwss = create_list(:public_water_system, 3)
      create(:violations_summary, pwsid: pwss[0].pwsid, paperwork_violations_5yr: 1)
      create(:violations_summary, pwsid: pwss[1].pwsid, paperwork_violations_5yr: 5)
      create(:violations_summary, pwsid: pwss[2].pwsid, paperwork_violations_5yr: 10)

      result = ViolationsSummary.histogram_bins("paperwork_violations_5yr")

      expect(result[:domain_min]).to eq(1)
      expect(result[:domain_max]).to eq(10)
      expect(result[:bins]).to be_an(Array)
      expect(result[:bins]).not_to be_empty
      expect(result[:bins].first).to include(:min, :max, :count)
      expect(result[:bins].sum { |b| b[:count] }).to eq(3)
    end

    it "excludes nil and zero values" do
      pws = create(:public_water_system)
      create(:violations_summary, pwsid: pws.pwsid, paperwork_violations_5yr: 0)

      result = ViolationsSummary.histogram_bins("paperwork_violations_5yr")

      expect(result[:bins]).to be_empty
      expect(result[:domain_min]).to eq(0)
      expect(result[:domain_max]).to eq(0)
    end

    it "returns empty result when no rows exist" do
      result = ViolationsSummary.histogram_bins("paperwork_violations_5yr")

      expect(result).to eq({bins: [], domain_min: 0, domain_max: 0})
    end

    it "handles single-value data (domain_min == domain_max)" do
      pwss = create_list(:public_water_system, 2)
      create(:violations_summary, pwsid: pwss[0].pwsid, paperwork_violations_5yr: 3)
      create(:violations_summary, pwsid: pwss[1].pwsid, paperwork_violations_5yr: 3)

      result = ViolationsSummary.histogram_bins("paperwork_violations_5yr")

      expect(result[:domain_min]).to eq(3)
      expect(result[:domain_max]).to eq(3)
      expect(result[:bins].sum { |b| b[:count] }).to eq(2)
    end
  end
end
