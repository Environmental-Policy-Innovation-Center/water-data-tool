module Etl
  module TypeCaster
    def cast_int(val) = normalize(val)&.to_i
    def cast_dec(val) = normalize(val)&.to_d
    def cast_string(val) = normalize(val)

    def cast_bool(val)
      normalized = normalize(val)
      return nil if normalized.nil?
      return nil if normalized.upcase == "NO INFORMATION"
      %w[Y YES].include?(normalized.upcase)
    end

    # Source scores are stored as 0–1 floats; multiply by 100 at import time.
    def cast_score(val) = normalize(val)&.then { |v| (v.to_f * 100).round(2) }

    private

    def normalize(val)
      return nil if val.nil?
      stripped = val.strip
      stripped unless stripped.empty? || stripped.upcase == "NA"
    end
  end
end
