require "net/http"
require "fileutils"

module CartographicLoader
  module_function

  def build_pg_connection_string(config)
    # Handle URL-based config (production with DATABASE_URL)
    if config[:url]
      uri = URI.parse(config[:url])
      parts = []
      parts << "host=#{uri.host}" if uri.host
      parts << "port=#{uri.port}" if uri.port
      parts << "dbname=#{uri.path&.delete_prefix("/")}" if uri.path
      parts << "user=#{uri.user}" if uri.user
      parts << "password=#{uri.password}" if uri.password
      return parts.join(" ")
    end

    parts = []
    parts << "host=#{config[:host]}" if config[:host]
    parts << "port=#{config[:port]}" if config[:port]
    parts << "dbname=#{config[:database]}" if config[:database]
    parts << "user=#{config[:username]}" if config[:username]
    parts << "password=#{config[:password]}" if config[:password]
    parts.join(" ")
  end

  def download_file(url, destination)
    uri = URI.parse(url)
    raise "Only HTTPS URLs are permitted" unless uri.is_a?(URI::HTTPS)

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Get.new(uri)
      http.request(request) do |response|
        raise "Download failed: #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

        File.open(destination, "wb") do |file|
          response.read_body { |chunk| file.write(chunk) }
        end
      end
    end
  end
end

namespace :cartographic do
  desc "Load Census Bureau 2022 cartographic boundaries (states, counties, places) via ogr2ogr"
  task load: :environment do
    # Guard: ogr2ogr must be available
    unless system("which ogr2ogr > /dev/null 2>&1")
      abort "ogr2ogr not found. Install GDAL: brew install gdal (macOS) or apt-get install gdal-bin (Linux)"
    end

    tmp_dir = Rails.root.join("tmp/cartographic")
    FileUtils.mkdir_p(tmp_dir)

    layers = [
      {
        zip_url: "https://www2.census.gov/geo/tiger/GENZ2022/shp/cb_2022_us_state_500k.zip",
        shapefile: "cb_2022_us_state_500k.shp",
        staging_table: "cartographic_states_staging",
        target_table: "cartographic_states",
        columns: "gid, statefp, stusps, name, geoid, geom"
      },
      {
        zip_url: "https://www2.census.gov/geo/tiger/GENZ2022/shp/cb_2022_us_county_500k.zip",
        shapefile: "cb_2022_us_county_500k.shp",
        staging_table: "cartographic_counties_staging",
        target_table: "cartographic_counties",
        columns: "gid, statefp, countyfp, geoid, name, namelsad, stusps, geom"
      },
      {
        zip_url: "https://www2.census.gov/geo/tiger/GENZ2022/shp/cb_2022_us_place_500k.zip",
        shapefile: "cb_2022_us_place_500k.shp",
        staging_table: "cartographic_places_staging",
        target_table: "cartographic_places",
        columns: "gid, statefp, placefp, geoid, name, namelsad, stusps, affgeoid, geom"
      }
    ]

    conn = ApplicationRecord.connection
    db_config = ApplicationRecord.connection_db_config.configuration_hash
    pg_conn_string = CartographicLoader.build_pg_connection_string(db_config)

    layers.each do |layer|
      zip_path = tmp_dir.join(File.basename(layer[:zip_url]))
      shp_path = tmp_dir.join(layer[:shapefile])

      # Download if not already cached
      unless zip_path.exist?
        puts "  Downloading #{File.basename(layer[:zip_url])}..."
        CartographicLoader.download_file(layer[:zip_url], zip_path)
      end

      # Unzip (overwrites existing) — array form avoids shell interpretation
      puts "  Extracting #{File.basename(zip_path)}..."
      system("unzip", "-o", "-q", zip_path.to_s, "-d", tmp_dir.to_s)

      abort "Shapefile not found: #{shp_path}" unless shp_path.exist?

      # Load into staging table via ogr2ogr — array form avoids shell injection
      puts "  Loading #{layer[:target_table]} via ogr2ogr..."
      success = system(
        "ogr2ogr",
        "-f", "PostgreSQL",
        "PG:#{pg_conn_string}",
        shp_path.to_s,
        "-nln", layer[:staging_table],
        "-overwrite",
        "-nlt", "PROMOTE_TO_MULTI",
        "-lco", "GEOMETRY_NAME=geom",
        "-lco", "FID=gid",
        "-lco", "PRECISION=NO",
        "-t_srs", "EPSG:4326"
      )

      abort "ogr2ogr failed for #{layer[:target_table]}" unless success

      # Move data from staging to target table, then clean up
      conn.execute("TRUNCATE #{layer[:target_table]}")
      conn.execute(<<~SQL)
        INSERT INTO #{layer[:target_table]} (#{layer[:columns]})
        SELECT #{layer[:columns]} FROM #{layer[:staging_table]}
      SQL
      conn.execute("DROP TABLE IF EXISTS #{layer[:staging_table]}")

      count = conn.select_value("SELECT COUNT(*) FROM #{layer[:target_table]}")
      puts "  #{layer[:target_table]}: #{count} rows loaded"
    end

    puts "✓ Cartographic boundaries loaded."
  end
end
