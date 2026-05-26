require "rails_helper"

RSpec.describe FilterRegistry do
  describe ".permit_arguments" do
    it "includes capped trend keys aligned with trend_data columns and UI" do
      flat = permit_flat_keys(described_class.permit_arguments)
      expect(flat).to include(:population_pct_change_capped_min, :population_pct_change_capped_max)
      expect(flat).to include(:mhi_pct_change_capped_min, :mhi_pct_change_capped_max)
      expect(flat).not_to include(:population_pct_change_min)
    end

    it "includes array-shaped permit hash entries" do
      args = described_class.permit_arguments
      expect(args.last).to be_a(Hash)
      expect(args.last.keys).to include(:owner_type, :primacy_type, :pop_cat_5, :most_common_rate_tier)
    end

    it "includes violations health subcat min/max keys" do
      flat = permit_flat_keys(described_class.permit_arguments)
      expect(flat).to include(:groundwater_rule_5yr_min, :lead_and_copper_10yr_max)
    end
  end

  describe ".health_subcats_all" do
    it "matches the union of 5yr and 10yr lists from config" do
      expect(described_class.health_subcats_all).to eq(
        described_class.health_subcat_5yr + described_class.health_subcat_10yr
      )
    end
  end

  describe ".client_payload" do
    it "includes version and range groups" do
      payload = described_class.client_payload
      expect(payload[:version]).to eq(1)
      expect(payload[:range_column_groups]).to have_key(:demographics)
      expect(payload[:range_column_groups][:demographics][:columns]).to include("poverty_rate")
    end
  end

  describe ".histogram_field_config" do
    it "maps columns to models, formats, and group-level extras" do
      cfg = described_class.histogram_field_config
      expect(cfg[:poverty_rate]).to eq({model: Demographic, format: "percent"})
      expect(cfg[:median_household_income]).to eq({model: Demographic, format: "currency"})
      expect(cfg[:population_pct_change_capped]).to eq({model: TrendDatum, format: "percent_change"})
      expect(cfg[:paperwork_violations_5yr]).to eq({model: ViolationsSummary, format: "count"})
    end

    it "includes every demographic range column from config" do
      cols = described_class.demographic_range_columns
      cfg = described_class.histogram_field_config
      cols.each { |c| expect(cfg).to have_key(c) }
    end
  end

  def permit_flat_keys(args)
    args.flat_map do |x|
      case x
      when Hash
        x.keys
      else
        x
      end
    end
  end
end
