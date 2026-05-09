module Histogrammable
  extend ActiveSupport::Concern

  class_methods do
    # Returns histogram bucket data for a numeric column.
    # min_threshold: rows where column <= this value are excluded. Pass nil to include all non-null rows.
    def histogram_bins(field, num_bins: 50, min_threshold: 0)
      quoted = connection.quote_column_name(field)
      scope = where.not(field => nil)
      scope = scope.where("#{quoted} > ?", min_threshold) if min_threshold

      min_val, max_val = scope.pick(Arel.sql("MIN(#{quoted})"), Arel.sql("MAX(#{quoted})"))
      return {bins: [], domain_min: 0, domain_max: 0} if min_val.nil?

      upper_bound = max_val + 1
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
end
