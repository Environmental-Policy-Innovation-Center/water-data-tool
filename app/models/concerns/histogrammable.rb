module Histogrammable
  extend ActiveSupport::Concern

  class_methods do
    # Returns histogram bucket data for a numeric column.
    #
    # format:        Controls domain clamping and bin count strategy.
    #                "percent"        → fixed domain 0–100, exactly 20 bins of 5pp each
    #                "percent_change" → fixed domain −200–+200, exactly 40 bins of 10pp each
    #                "count"          → adaptive: min(domain_max, 30) bins; good for small-range integers
    #                "currency" / nil → 30 equal-width bins
    # num_bins:      Explicit override; rarely needed — format drives this automatically.
    # min_threshold: Rows where column <= this value are excluded before computing range.
    #                Pass nil to include all non-null rows (required for signed/change fields).
    #
    # The response always contains exactly num_bins entries with uniform theoretical boundaries,
    # including zero-count entries for empty buckets. This keeps bar positioning and handle
    # coordinates consistent regardless of data distribution.
    #
    # Callers must validate `field` against an allowlist — see ALLOWED_FIELDS in
    # PublicWaterSystems::HistogramsController.
    def histogram_bins(field, format: nil, num_bins: nil, min_threshold: 0)
      quoted = connection.quote_column_name(field)
      scope = where.not(field => nil)

      if format == "percent"
        domain_min = 0
        domain_max = 100
        num_bins = 20
        upper_bound = 100
        # Domain is fixed 0–100; 0% is a valid data point, so no min_threshold filter here.
      elsif format == "percent_change"
        # Signed field — default zero-exclusion doesn't apply; an explicit non-zero threshold is respected.
        scope = scope.where("#{quoted} > ?", min_threshold) if min_threshold&.nonzero?
        domain_min = -200
        domain_max = 200
        num_bins = 40
        upper_bound = 200
      else
        scope = scope.where("#{quoted} > ?", min_threshold) if min_threshold
        domain_min, domain_max = scope.pick(Arel.sql("MIN(#{quoted})"), Arel.sql("MAX(#{quoted})"))
        return {bins: [], domain_min: 0, domain_max: 0} if domain_min.nil?

        num_bins ||= if format == "count"
          (domain_max - domain_min + 1).to_i.clamp(1, 30)
        else
          30
        end
        upper_bound = domain_max + 1
      end

      bin_width = (upper_bound.to_f - domain_min) / num_bins
      q_min = connection.quote(domain_min)
      q_upper = connection.quote(upper_bound)
      q_bins = connection.quote(num_bins)

      rows = scope.select(
        Arel.sql(
          "width_bucket(#{quoted}::numeric, #{q_min}, #{q_upper}, #{q_bins}) AS bucket,
           COUNT(*) AS bin_count"
        )
      ).group("bucket").order("bucket")

      # Clamp underflow (0) and overflow (num_bins+1) into the first/last bin so values
      # at exactly domain_min or domain_max are never lost (e.g. poverty_rate = 100%).
      bucket_map = rows.each_with_object({}) do |r, h|
        bucket = r.bucket.to_i.clamp(1, num_bins)
        h[bucket] = (h[bucket] || 0) + r.bin_count.to_i
      end

      bins = num_bins.times.map do |i|
        {
          min: domain_min + i * bin_width,
          max: domain_min + (i + 1) * bin_width,
          count: bucket_map.fetch(i + 1, 0)
        }
      end

      {bins: bins, domain_min: domain_min, domain_max: domain_max}
    end
  end
end
