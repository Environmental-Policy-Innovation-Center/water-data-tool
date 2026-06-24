require "csv"

module Etl
  module Importers
    class SabsPwsidCounty < Etl::FileImporter
      def parse(content)
        grouped = Hash.new { |h, k| h[k] = [] }

        CSV.parse(content, headers: true) do |row|
          # Skip blank rows. If every county_served value for a PWSID is blank,
          # that PWSID won't appear in the parsed output and import! skips it —
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
        return Etl::ImportResult.imported(file_key: file_key) if rows.empty?

        known_pwsids = PublicWaterSystem.where(pwsid: rows.map { |r| r[:pwsid] }).pluck(:pwsid).to_set
        valid_rows = rows.select { |r| known_pwsids.include?(r[:pwsid]) }

        PublicWaterSystem.upsert_all(valid_rows, unique_by: :pwsid, update_only: [:counties]) if valid_rows.any?
        Etl::ImportResult.imported(file_key: file_key)
      end
    end
  end
end
