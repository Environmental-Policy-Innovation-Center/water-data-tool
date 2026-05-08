module Etl
  # Runs PostGIS-derived data steps after epa_sabs_geoms.geojson is imported.
  # Equivalent to the legacy post_import_scripts.sql.
  module PostImportSteps
    module_function

    def call(imported_files:)
      # imported_files is an array of file_keys (e.g. ["epa_sabs", "epa_sabs_geoms"])
      # If no files were imported, skip all steps to avoid unnecessary DB work and
      return if imported_files.empty?

      # If any files were imported, bust the tile cache to ensure all tiles are regenerated with fresh data.
      # This is a broad hammer but ensures no stale tiles are served after any import.
      bust_tile_cache
      TileCacheWarmJob.perform_later

      # The following steps are only necessary if the geometry file was imported.
      return unless imported_files.include?('epa_sabs_geoms')

      # Tee up initial geoms repair and enrichment steps before refreshing
      fix_invalid_geometries
      generate_centroids
      Rake::Task['cartographic:load'].invoke # Refresh before the spacial joins

      # Assign state codes and county associations based on the new geometries,
      # then rebuild spatial indexes and place crosswalks that depend on those joins.
      assign_state_codes
      build_county_associations
      rebuild_spatial_indexes
      build_place_crosswalks

    end

    # Repair invalid geometries using ST_Buffer trick. Runs until none remain
    # or until MAX_REPAIR_ITERATIONS is reached (guard against pathological data).
    MAX_REPAIR_ITERATIONS = 10

    def fix_invalid_geometries
      conn = ApplicationRecord.connection
      all_valid = false
      MAX_REPAIR_ITERATIONS.times do |i|
        result = conn.execute(<<~SQL)
          UPDATE service_area_geometries
          SET geom = ST_Buffer(geom, 0)
          WHERE ST_IsValid(geom) = false
        SQL
        if result.cmd_tuples == 0
          Rails.logger.info("[ETL] fix_invalid_geometries: complete after #{i} iteration(s)")
          all_valid = true
          break
        end
        Rails.logger.info("[ETL] fix_invalid_geometries: iteration #{i + 1} repaired #{result.cmd_tuples} geometry(ies)")
      end
      unless all_valid
        Rails.logger.warn("[ETL] fix_invalid_geometries reached #{MAX_REPAIR_ITERATIONS} iterations — some geometries may still be invalid")
      end
    end

    # Populate centroid using ST_PointOnSurface (guaranteed inside polygon).
    def generate_centroids
      result = ApplicationRecord.connection.execute(<<~SQL)
        UPDATE service_area_geometries
        SET centroid = ST_PointOnSurface(geom)
      SQL
      Rails.logger.info("[ETL] generate_centroids: updated #{result.cmd_tuples} row(s)")
    end

    # Join centroids to cartographic_states to assign the stusps code.
    def assign_state_codes
      result = ApplicationRecord.connection.execute(<<~SQL)
        UPDATE public_water_systems pws
        SET stusps = cs.stusps
        FROM service_area_geometries sag
        JOIN cartographic_states cs ON ST_Intersects(sag.centroid, cs.geom)
        WHERE pws.pwsid = sag.pwsid
          AND sag.centroid IS NOT NULL
      SQL
      Rails.logger.info("[ETL] assign_state_codes: updated #{result.cmd_tuples} row(s)")
    end

    # Aggregate intersecting county names into the denormalized counties column.
    def build_county_associations
      result = ApplicationRecord.connection.execute(<<~SQL)
        UPDATE public_water_systems pws
        SET counties = sub.counties
        FROM (
          SELECT sag.pwsid,
                 array_to_string(array_agg(cc.namelsad || ', ' || cc.stusps ORDER BY cc.namelsad), '; ') AS counties
          FROM cartographic_counties cc
          JOIN service_area_geometries sag ON ST_Intersects(sag.geom, cc.geom)
          WHERE GeometryType(ST_Intersection(sag.geom, cc.geom)) IN ('POLYGON', 'MULTIPOLYGON')
          GROUP BY sag.pwsid
        ) sub
        WHERE pws.pwsid = sub.pwsid
      SQL
      Rails.logger.info("[ETL] build_county_associations: updated #{result.cmd_tuples} row(s)")
    end

    # Rebuild the place_system_crosswalks table from spatial intersections.
    # Runs atomically: the table is either fully rebuilt or left untouched.
    #
    # Single-pass CTE: computes ST_Intersection once per pair, derives both
    # fractions from that result, and filters below-threshold pairs inline.
    # The explicit && bounding-box pre-filter ensures the GiST index is used.
    # Must run after rebuild_spatial_indexes so the index is fresh.
    def build_place_crosswalks
      ApplicationRecord.connection.transaction do
        ApplicationRecord.connection.execute("DELETE FROM place_system_crosswalks")

        inserted = ApplicationRecord.connection.execute(<<~SQL).cmd_tuples
          WITH intersections AS (
            SELECT
              cp.geoid,
              sag.pwsid,
              ST_Intersection(sag.geom, cp.geom) AS ix_geom,
              ST_Area(sag.geom)                  AS sag_area,
              ST_Area(cp.geom)                   AS place_area
            FROM cartographic_places cp
            JOIN service_area_geometries sag
              ON sag.geom && cp.geom
             AND ST_Intersects(sag.geom, cp.geom)
          )
          INSERT INTO place_system_crosswalks
            (geoid, pwsid, fraction_of_service_area, fraction_of_place, created_at, updated_at)
          SELECT
            geoid,
            pwsid,
            ST_Area(ix_geom) / NULLIF(sag_area, 0),
            ST_Area(ix_geom) / NULLIF(place_area, 0),
            NOW(), NOW()
          FROM intersections
          WHERE ST_Area(ix_geom) / NULLIF(sag_area, 0)   >= 0.01
             OR ST_Area(ix_geom) / NULLIF(place_area, 0) >= 0.01
          ON CONFLICT (geoid, pwsid) DO NOTHING
        SQL

        Rails.logger.info("[ETL] build_place_crosswalks: inserted #{inserted} crosswalk(s)")
      end
    end

    # Truncate the tile_cache table so stale MVT tiles are regenerated on
    # the next request. Called by Etl::Importer after any successful import
    # (not just geometry) because tiles embed non-geometry attributes.
    def bust_tile_cache
      deleted = TileCache.delete_all
      Rails.logger.info("[ETL] bust_tile_cache: deleted #{deleted} cached tile(s)")
    end

    # Rebuild GiST spatial indexes and update query-planner statistics after
    # a bulk geometry import. REINDEX without CONCURRENTLY to stay
    # transaction-safe; ANALYZE refreshes planner statistics.
    def rebuild_spatial_indexes
      conn = ApplicationRecord.connection
      conn.execute("REINDEX INDEX index_service_area_geometries_on_geom")
      conn.execute("REINDEX INDEX index_service_area_geometries_on_centroid")
      conn.execute("ANALYZE service_area_geometries")
      Rails.logger.info("[ETL] rebuild_spatial_indexes: complete")
    end
  end
end
