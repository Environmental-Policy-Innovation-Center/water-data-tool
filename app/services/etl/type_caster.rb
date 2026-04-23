module Etl
  module TypeCaster
    def cast_int(val)
      return nil if val.nil?
      stripped = val.strip
      return nil if stripped.empty? || stripped.upcase == "NA"
      stripped.to_i
    end

    def cast_dec(val)
      return nil if val.nil?
      stripped = val.strip
      return nil if stripped.empty? || stripped.upcase == "NA"
      stripped.to_d
    end

    def cast_bool(val)
      return nil if val.nil?
      stripped = val.strip
      return nil if stripped.empty?
      %w[Y YES].include?(stripped.upcase)
    end

    # Source scores are stored as 0–1 floats; multiply by 100 at import time.
    def cast_score(val)
      return nil if val.nil?
      stripped = val.strip
      return nil if stripped.empty? || stripped.upcase == "NA"
      (stripped.to_f * 100).round(2)
    end
  end
end
