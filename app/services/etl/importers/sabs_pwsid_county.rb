require "csv"

module Etl
  module Importers
    class SabsPwsidCounty < Etl::FileImporter
      def parse(content)
        grouped = Hash.new { |h, k| h[k] = [] }

        CSV.parse(content, headers: true) do |row|
          # Skip blank rows. If a PWSID's every row is blank it won't appear
          # in the output, so import! leaves any existing county data untouched —
          # conservative by design: don't clear data we can't replace.
          next if row["county_served"].blank?

          pwsid = row["pwsid"]
          row["county_served"].split("; ").each do |county|
            grouped[pwsid] << county.strip
          end
        end

        grouped.map do |pwsid, counties|
          {pwsid: pwsid, counties: counties.uniq.sort.join("; ")}
        end
      end

      def import!(rows)
        return if rows.empty?

        known_pwsids = PublicWaterSystem.where(pwsid: rows.map { |r| r[:pwsid] }).pluck(:pwsid).to_set
        valid_rows = rows.select { |r| known_pwsids.include?(r[:pwsid]) }

        PublicWaterSystem.upsert_all(valid_rows, unique_by: :pwsid, update_only: [:counties]) if valid_rows.any?
      end
    end
  end
end
