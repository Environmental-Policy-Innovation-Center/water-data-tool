require "csv"

class PublicWaterSystemExporter
  BATCH_SIZE = 1000

  def initialize(scope)
    @scope = scope
  end

  # Preserves UI sort order — plucks sorted pwsids first, then batch-fetches rows via raw SQL.
  def to_csv_stream
    col_map = ColumnRegistry.csv_columns
    col_sql = col_map.values.join(", ")
    Enumerator.new do |stream|
      stream << CSV.generate_line(col_map.keys)
      sorted_ids = @scope.pluck(:pwsid)
      sorted_ids.each_slice(BATCH_SIZE) do |batch|
        rows_by_id = fetch_csv_batch(batch, col_sql).index_by { |r| r["pwsid"] }
        batch.each do |id|
          row = rows_by_id[id]
          stream << CSV.generate_line(row.values) if row
        end
      end
    end
  end

  # Streams a GeoJSON FeatureCollection in pwsid order (not UI sort order).
  # PostgreSQL via ST_AsGeoJSON + json_build_object; records are fetched in
  # cursor-based batches to keep memory usage flat regardless of result size.
  def to_geojson_stream
    Enumerator.new do |stream|
      stream << '{"type":"FeatureCollection","features":['
      first = true
      # Empty string is a valid sentinel: all EPA pwsids are non-empty, so
      # WHERE pws.pwsid > '' matches every row on the first iteration.
      last_pwsid = ""
      loop do
        rows = fetch_feature_batch(last_pwsid)
        break if rows.ntuples.zero?
        rows.each do |row|
          stream << "," unless first
          first = false
          stream << row["feature"]
          last_pwsid = row["pwsid"]
        end
        break if rows.ntuples < BATCH_SIZE
      end
      stream << "]}"
    end
  end

  private

  # SAFETY: all values are from frozen constants — never extend with user-supplied input.
  ASSOCIATION_JOINS = <<~SQL.freeze
    LEFT JOIN violations_summaries   vs  ON vs.pwsid  = pws.pwsid
    LEFT JOIN boil_water_summaries   bws ON bws.pwsid = pws.pwsid
    LEFT JOIN demographics           d   ON d.pwsid   = pws.pwsid
    LEFT JOIN trend_data             td  ON td.pwsid  = pws.pwsid
    LEFT JOIN environmental_justices ej  ON ej.pwsid  = pws.pwsid
    LEFT JOIN funding_summaries      fs  ON fs.pwsid  = pws.pwsid
    LEFT JOIN watershed_hazards      wh  ON wh.pwsid  = pws.pwsid
  SQL

  def properties_sql
    # json_build_object caps at 100 args (50 pairs) — slice at 49 and merge chunks with ||.
    @properties_sql ||= begin
      conn = ApplicationRecord.connection
      chunks = ColumnRegistry.geojson_columns.each_slice(49).map do |slice|
        pairs = slice.flat_map do |k, v|
          table, col = v.split(".")
          [conn.quote(k), "#{conn.quote_column_name(table)}.#{conn.quote_column_name(col)}"]
        end
        "jsonb_build_object(#{pairs.join(", ")})"
      end
      "(#{chunks.join(" || ")})::json"
    end
  end

  def filtered_ids_sql
    @filtered_ids_sql ||= @scope.unscope(:order).select("public_water_systems.pwsid").distinct.to_sql
  end

  def fetch_feature_batch(last_pwsid)
    quoted = ApplicationRecord.connection.quote(last_pwsid)
    ApplicationRecord.connection.execute(<<~SQL)
      SELECT
        pws.pwsid,
        json_build_object(
          'type', 'Feature',
          'geometry', ST_AsGeoJSON(sag.geom)::json,
          'properties', #{properties_sql}
        )::text AS feature
      FROM public_water_systems pws
      INNER JOIN (#{filtered_ids_sql}) filtered ON filtered.pwsid = pws.pwsid
      LEFT JOIN service_area_geometries sag ON sag.pwsid = pws.pwsid
      #{ASSOCIATION_JOINS}
      WHERE pws.pwsid > #{quoted}
      ORDER BY pws.pwsid
      LIMIT #{BATCH_SIZE}
    SQL
  end

  def fetch_csv_batch(pwsids, col_sql)
    conn = ApplicationRecord.connection
    quoted_ids = pwsids.map { |id| conn.quote(id) }.join(", ")
    conn.execute(<<~SQL)
      SELECT #{col_sql}
      FROM public_water_systems pws
      #{ASSOCIATION_JOINS}
      WHERE pws.pwsid IN (#{quoted_ids})
    SQL
  end
end
