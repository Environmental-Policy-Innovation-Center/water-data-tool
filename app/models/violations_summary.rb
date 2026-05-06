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
class ViolationsSummary < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :violations_summary

  validates :pwsid, presence: true

  def self.histogram_bins(field, num_bins: 50)
    quoted = connection.quote_column_name(field)
    scope = where.not(field => nil).where("#{quoted} > 0")
    min_val, max_val = scope.pick(Arel.sql("MIN(#{quoted})"), Arel.sql("MAX(#{quoted})"))
    return {bins: [], domain_min: 0, domain_max: 0} if min_val.nil?

    upper_bound = max_val + 1  # width_bucket upper bound is exclusive; +1 ensures max_val lands in the last bucket
    q_min = connection.quote(min_val)
    q_upper = connection.quote(upper_bound)
    q_bins = connection.quote(num_bins)
    rows = scope.select(
      Arel.sql(
        "width_bucket(#{quoted}::numeric, #{q_min}, #{q_upper}, #{q_bins}) AS bucket,
         MIN(#{quoted}) AS bin_min,
         MAX(#{quoted}) AS bin_max,
         COUNT(*) AS bin_count"
      )
    ).group("bucket").order("bucket")

    bins = rows.map { |r| {min: r.bin_min, max: r.bin_max, count: r.bin_count.to_i} }
    {bins: bins, domain_min: min_val, domain_max: max_val}
  end
end
