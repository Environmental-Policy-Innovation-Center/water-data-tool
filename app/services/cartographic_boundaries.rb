require "net/http"
require "fileutils"

class CartographicBoundaries
  include Etl::HttpFetcher

  IMPORT_FILE_URL = "cartographic-boundaries".freeze
  BOUNDARY_PATH = "cartographic-boundaries".freeze

  LAYERS = [
    {
      zip_file: "us_state_500k.zip",
      shapefile: "us_state_500k.shp",
      staging_table: "cartographic_states_staging",
      target_table: "cartographic_states",
      tile_layer: "states",
      columns: "gid, statefp, stusps, name, geoid, geom"
    },
    {
      zip_file: "us_county_500k.zip",
      shapefile: "us_county_500k.shp",
      staging_table: "cartographic_counties_staging",
      target_table: "cartographic_counties",
      tile_layer: "counties",
      columns: "gid, statefp, countyfp, geoid, name, namelsad, stusps, geom"
    },
    {
      zip_file: "us_place_500k.zip",
      shapefile: "us_place_500k.shp",
      staging_table: "cartographic_places_staging",
      target_table: "cartographic_places",
      tile_layer: "places",
      columns: "gid, statefp, placefp, geoid, name, namelsad, stusps, affgeoid, geom"
    }
  ].freeze

  def self.load(force: false)
    new.load(force: force)
  end

  # When nothing is newer it skips without recording a DataImport record
  def load(force: false)
    layers = force ? LAYERS : stale_layers
    return Etl::ImportResult.skipped(file_key: IMPORT_FILE_URL) if layers.empty?

    raise "ogr2ogr not found. Install GDAL: brew install gdal (macOS) or apt-get install gdal-bin (Linux)" unless system("which ogr2ogr > /dev/null 2>&1")

    tmp_dir = Rails.root.join("tmp/cartographic")
    FileUtils.mkdir_p(tmp_dir)

    conn = ApplicationRecord.connection
    config = ApplicationRecord.connection_db_config.configuration_hash
    pg_conn_string, pg_password = build_pg_connection_string(config)

    layers.each { |layer| load_layer(layer, tmp_dir, conn, pg_conn_string, pg_password) }
    record_import
    Etl::ImportResult.imported(
      file_key: IMPORT_FILE_URL,
      changed_boundary_layers: layers.map { |layer| layer[:tile_layer] }
    )
  end

  private

  # Mirrors Etl::FileImporter#needs_import? — layers whose source is newer than the last import (all on first run).
  def stale_layers
    last_import = DataImport.where(file_url: IMPORT_FILE_URL).maximum(:imported_at)
    return LAYERS if last_import.nil?

    LAYERS.select { |layer| source_newer_than?(zip_url(layer), last_import) }
  end

  def source_newer_than?(url, last_import)
    last_modified = last_modified_at(url)
    last_modified.nil? || last_modified > last_import
  end

  def record_import
    DataImport.create!(file_url: IMPORT_FILE_URL, imported_at: Time.current)
  end

  def load_layer(layer, tmp_dir, conn, pg_conn_string, pg_password)
    zip_path = tmp_dir.join(layer[:zip_file])
    shp_path = tmp_dir.join(layer[:shapefile])

    unless zip_path.exist?
      Rails.logger.info("[Cartographic] Downloading #{layer[:zip_file]}...")
      download_file(zip_url(layer), zip_path)
    end

    raise "unzip failed for #{zip_path}" unless system("unzip", "-o", "-q", zip_path.to_s, "-d", tmp_dir.to_s)
    raise "Shapefile not found: #{shp_path}" unless shp_path.exist?

    Rails.logger.info("[Cartographic] Loading #{layer[:target_table]} via ogr2ogr...")
    env = pg_password ? {"PGPASSWORD" => pg_password} : {}
    success = system(
      env,
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

    target = conn.quote_table_name(layer[:target_table])
    staging = conn.quote_table_name(layer[:staging_table])
    cols = layer[:columns].split(",").map { |c| conn.quote_column_name(c.strip) }.join(", ")

    # Each layer's swap is atomic: a failed INSERT leaves the target untouched.
    # There is no cross-layer rollback — if layer 2 fails, layer 1 is already
    # committed. A re-run will correct the partial state.
    conn.transaction do
      conn.execute("TRUNCATE #{target}")
      conn.execute("INSERT INTO #{target} (#{cols}) SELECT #{cols} FROM #{staging}")
      conn.execute("DROP TABLE IF EXISTS #{staging}")
    end

    count = conn.select_value("SELECT COUNT(*) FROM #{target}")
    Rails.logger.info("[Cartographic] #{layer[:target_table]}: #{count} rows loaded")

    # Remove extracted shapefile components — the zip is kept for re-run caching.
    basename = File.basename(layer[:shapefile], ".shp")
    Dir.glob(tmp_dir.join("#{basename}.*")).each { |f| FileUtils.rm_f(f) }
  end

  def zip_url(layer)
    base_url = ENV.fetch("ETL_SOURCE_URL") { raise "ETL_SOURCE_URL is not set" }.chomp("/")
    "#{base_url}/#{BOUNDARY_PATH}/#{layer.fetch(:zip_file)}"
  end

  # Returns [conn_string, password]. Password is kept out of the connection
  # string so it isn't visible in the ogr2ogr argument list (e.g. via ps aux).
  # Callers pass it via the PGPASSWORD environment variable instead.
  def build_pg_connection_string(config)
    if config[:url]
      uri = URI.parse(config[:url])
      parts = []
      parts << "host=#{uri.host}" if uri.host
      parts << "port=#{uri.port}" if uri.port
      parts << "dbname=#{uri.path&.delete_prefix("/")}" if uri.path
      parts << "user=#{uri.user}" if uri.user
      return [parts.join(" "), uri.password.presence]
    end

    parts = []
    parts << "host=#{config[:host]}" if config[:host]
    parts << "port=#{config[:port]}" if config[:port]
    parts << "dbname=#{config[:database]}" if config[:database]
    parts << "user=#{config[:username]}" if config[:username]
    [parts.join(" "), config[:password].presence]
  end

  def download_file(url, destination)
    tmpfile = stream_to_tempfile(url)
    FileUtils.cp(tmpfile.path, destination)
  ensure
    tmpfile&.close!
  end
end
