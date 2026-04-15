module Etl
  # Runs PostGIS-derived data steps after epa_sabs_geoms.geojson is imported.
  # Equivalent to the legacy post_import_scripts.sql.
  module PostImportSteps
    module_function

    def call
      fix_invalid_geometries
      generate_centroids
      assign_state_codes
      build_county_associations
      build_place_crosswalks
      rebuild_spatial_indexes
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
    def build_place_crosswalks
      ApplicationRecord.connection.transaction do
        ApplicationRecord.connection.execute("DELETE FROM place_system_crosswalks")

        inserted = ApplicationRecord.connection.execute(<<~SQL).cmd_tuples
          INSERT INTO place_system_crosswalks (geoid, pwsid, created_at, updated_at)
          SELECT cp.geoid, sag.pwsid, NOW(), NOW()
          FROM cartographic_places cp
          JOIN service_area_geometries sag ON ST_Intersects(sag.geom, cp.geom)
          ON CONFLICT (geoid, pwsid) DO NOTHING
        SQL

        ApplicationRecord.connection.execute(<<~SQL)
          UPDATE place_system_crosswalks psc
          SET fraction_of_service_area = ST_Area(ST_Intersection(sag.geom, cp.geom)) / NULLIF(ST_Area(sag.geom), 0),
              fraction_of_place        = ST_Area(ST_Intersection(sag.geom, cp.geom)) / NULLIF(ST_Area(cp.geom), 0)
          FROM service_area_geometries sag
          JOIN cartographic_places cp ON ST_Intersects(sag.geom, cp.geom)
          WHERE psc.pwsid = sag.pwsid AND psc.geoid = cp.geoid
        SQL

        pruned = ApplicationRecord.connection.execute(<<~SQL).cmd_tuples
          DELETE FROM place_system_crosswalks
          WHERE fraction_of_service_area < 0.01 OR fraction_of_place < 0.01
        SQL

        Rails.logger.info("[ETL] build_place_crosswalks: inserted #{inserted}, pruned #{pruned} crosswalk(s)")
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
