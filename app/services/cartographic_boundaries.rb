require "net/http"
require "fileutils"

class CartographicBoundaries
  LAYERS = [
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
  ].freeze

  def self.load
    new.load
  end

  def load
    raise "ogr2ogr not found. Install GDAL: brew install gdal (macOS) or apt-get install gdal-bin (Linux)" unless system("which ogr2ogr > /dev/null 2>&1")

    tmp_dir = Rails.root.join("tmp/cartographic")
    FileUtils.mkdir_p(tmp_dir)

    conn = ApplicationRecord.connection
    pg_conn_string = build_pg_connection_string(ApplicationRecord.connection_db_config.configuration_hash)

    LAYERS.each { |layer| load_layer(layer, tmp_dir, conn, pg_conn_string) }
  end

  private

  def load_layer(layer, tmp_dir, conn, pg_conn_string)
    zip_path = tmp_dir.join(File.basename(layer[:zip_url]))
    shp_path = tmp_dir.join(layer[:shapefile])

    unless zip_path.exist?
      Rails.logger.info("[Cartographic] Downloading #{File.basename(layer[:zip_url])}...")
      download_file(layer[:zip_url], zip_path)
    end

    raise "unzip failed for #{zip_path}" unless system("unzip", "-o", "-q", zip_path.to_s, "-d", tmp_dir.to_s)
    raise "Shapefile not found: #{shp_path}" unless shp_path.exist?

    Rails.logger.info("[Cartographic] Loading #{layer[:target_table]} via ogr2ogr...")
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
    raise "ogr2ogr failed for #{layer[:target_table]}" unless success

    target  = conn.quote_table_name(layer[:target_table])
    staging = conn.quote_table_name(layer[:staging_table])
    cols    = layer[:columns].split(",").map { |c| conn.quote_column_name(c.strip) }.join(", ")

    conn.execute("TRUNCATE #{target}")
    conn.execute("INSERT INTO #{target} (#{cols}) SELECT #{cols} FROM #{staging}")
    conn.execute("DROP TABLE IF EXISTS #{staging}")

    count = conn.select_value("SELECT COUNT(*) FROM #{target}")
    Rails.logger.info("[Cartographic] #{layer[:target_table]}: #{count} rows loaded")
  end

  def build_pg_connection_string(config)
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
