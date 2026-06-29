module Etl
  # Runs PostGIS-derived data steps after epa_sabs_geoms.geojson is imported.
  # Equivalent to the legacy post_import_scripts.sql.
  module PostImportSteps
    module_function

    def call(imported_files: nil, import_results: nil)
      if import_results.nil?
        raise ArgumentError, "import_results metadata is required" if imported_files.nil?

        return legacy_call(imported_files)
      end

      validate_import_results!(import_results)

      backfill_missing_generalized_geometries

      return if import_results.empty?

      return legacy_call(import_results.map(&:file_key)) if import_results.any?(&:full_refresh_required)

      changed_pwsids = import_results.flat_map(&:changed_pwsids).compact.uniq
      changed_layers = import_results.flat_map(&:changed_layers).compact.uniq
      geometry_pwsids = import_results.select(&:geometry_changed).flat_map(&:changed_pwsids).compact.uniq
      previous_geometry_bboxes = import_results.flat_map(&:previous_geometry_bboxes).compact.uniq
      affected_place_geoids = []

      if geometry_pwsids.any?
        fix_invalid_geometries(pwsids: geometry_pwsids)
        generate_centroids(pwsids: geometry_pwsids)
        generate_generalized_geometries(pwsids: geometry_pwsids)
        CartographicBoundaries.load
        assign_state_codes(pwsids: geometry_pwsids)
        analyze_spatial_tables
        affected_place_geoids = build_place_crosswalks(pwsids: geometry_pwsids)
      end

      if changed_pwsids.empty? || changed_layers.empty?
        log_selective_refresh(import_results: import_results, impacted_tile_count: 0, refresh_job_count: 0)
        return
      end

      impacts = {}
      pws_layers = changed_layers - ["places"]
      place_layers = changed_layers & ["places"]
      if pws_layers.any?
        pws_impacts = if previous_geometry_bboxes.any?
          TileImpact.for_pwsids(changed_pwsids, layers: pws_layers, additional_bboxes: previous_geometry_bboxes)
        else
          TileImpact.for_pwsids(changed_pwsids, layers: pws_layers)
        end
        impacts.merge!(pws_impacts)
      end
      impacts.merge!(TileImpact.for_place_geoids(affected_place_geoids, layers: place_layers)) if place_layers.any?
      refresh_job_count = TileImpact.enqueue_refreshes(impacts)
      log_selective_refresh(
        import_results: import_results,
        impacted_tile_count: impacts.values.sum(&:size),
        refresh_job_count: refresh_job_count
      )
    end

    def validate_import_results!(import_results)
      invalid = import_results.reject { |result| result.is_a?(Etl::ImportResult) }
      return if invalid.empty?

      raise ArgumentError, "import_results must contain only Etl::ImportResult objects"
    end

    def log_selective_refresh(import_results:, impacted_tile_count:, refresh_job_count:)
      imported_files = import_results.map(&:file_key)
      changed_pwsids = import_results.flat_map(&:changed_pwsids).compact.uniq
      changed_layers = import_results.flat_map(&:changed_layers).compact.uniq
      Rails.logger.info(
        "[ETL] selective refresh: imported_files=#{imported_files.inspect} " \
        "changed_pwsids=#{changed_pwsids.size} changed_layers=#{changed_layers.inspect} " \
        "impacted_tiles=#{impacted_tile_count} refresh_jobs=#{refresh_job_count} full_refresh_required=false"
      )
    end

    def legacy_call(imported_files)
      # imported_files is an array of successfully-imported file keys, e.g. ["epa_sabs", "epa_sabs_geoms"]
      return if imported_files.blank?

      Rails.logger.info(
        "[ETL] full refresh requested: imported_files=#{Array(imported_files).inspect} full_refresh_required=true"
      )

      unless imported_files.include?("epa_sabs_geoms")
        bust_tile_cache
        TileCacheWarmJob.perform_later
        return
      end

      # Tee up initial geoms repair and enrichment steps before refreshing
      fix_invalid_geometries
      generate_centroids
      generate_generalized_geometries
      CartographicBoundaries.load

      # Assign state codes and county associations based on the new geometries,
      # then rebuild spatial indexes and place crosswalks that depend on those joins.
      assign_state_codes
      rebuild_spatial_indexes
      build_place_crosswalks
      bust_tile_cache
      TileCacheWarmJob.perform_later
    end

    # Repair invalid geometries using ST_Buffer trick. Runs until none remain
    # or until MAX_REPAIR_ITERATIONS is reached (guard against pathological data).
    MAX_REPAIR_ITERATIONS = 10
    GENERALIZED_GEOMETRY_BACKFILL_BATCH_SIZE = 500

    def fix_invalid_geometries(pwsids: nil)
      all_valid = false
      MAX_REPAIR_ITERATIONS.times do |i|
        scope = ServiceAreaGeometry.where("ST_IsValid(geom) = false")
        scope = scope.where(pwsid: pwsids) if pwsids.present?
        updated = scope.update_all("geom = ST_Buffer(geom, 0)")

        if updated == 0
          Rails.logger.info("[ETL] fix_invalid_geometries: complete after #{i} iteration(s)")
          all_valid = true
          break
        end
        Rails.logger.info("[ETL] fix_invalid_geometries: iteration #{i + 1} repaired #{updated} geometry(ies)")
      end
      unless all_valid
        Rails.logger.warn("[ETL] fix_invalid_geometries reached #{MAX_REPAIR_ITERATIONS} iterations — some geometries may still be invalid")
      end
    end

    # Populate centroid using ST_PointOnSurface (guaranteed inside polygon).
    def generate_centroids(pwsids: nil)
      scope = ServiceAreaGeometry.where.not(geom: nil)
      scope = scope.where(pwsid: pwsids) if pwsids.present?
      updated = scope.update_all("centroid = ST_PointOnSurface(geom)")

      Rails.logger.info("[ETL] generate_centroids: updated #{updated} row(s)")
    end

    def generate_generalized_geometries(pwsids: nil)
      sql = <<~SQL
        UPDATE service_area_geometries
        SET
          geom_z0_4 = ST_Multi(ST_SimplifyPreserveTopology(geom, 0.05)),
          geom_z5 = ST_Multi(ST_SimplifyPreserveTopology(geom, 0.01)),
          geom_z6 = ST_Multi(ST_SimplifyPreserveTopology(geom, 0.005)),
          geom_z7 = ST_Multi(ST_SimplifyPreserveTopology(geom, 0.001)),
          updated_at = NOW()
        WHERE geom IS NOT NULL
      SQL
      sql << " AND pwsid = ANY($1::text[])" if pwsids.present?

      updated = ApplicationRecord.connection.exec_update(
        sql,
        "PostImportSteps#generate_generalized_geometries",
        pwsid_binds(pwsids)
      )
      Rails.logger.info("[ETL] generate_generalized_geometries: updated #{updated} row(s)")
    end

    def backfill_missing_generalized_geometries
      total_updated = 0

      loop do
        sql = <<~SQL
          WITH rows_to_update AS (
            SELECT id
            FROM service_area_geometries
            WHERE geom IS NOT NULL
              AND (
                geom_z0_4 IS NULL
                OR geom_z5 IS NULL
                OR geom_z6 IS NULL
                OR geom_z7 IS NULL
              )
            ORDER BY id
            LIMIT #{GENERALIZED_GEOMETRY_BACKFILL_BATCH_SIZE}
          )
          UPDATE service_area_geometries sag
          SET
            geom_z0_4 = ST_Multi(ST_SimplifyPreserveTopology(sag.geom, 0.05)),
            geom_z5 = ST_Multi(ST_SimplifyPreserveTopology(sag.geom, 0.01)),
            geom_z6 = ST_Multi(ST_SimplifyPreserveTopology(sag.geom, 0.005)),
            geom_z7 = ST_Multi(ST_SimplifyPreserveTopology(sag.geom, 0.001)),
            updated_at = NOW()
          FROM rows_to_update
          WHERE sag.id = rows_to_update.id
        SQL

        updated = ApplicationRecord.connection.exec_update(
          sql,
          "PostImportSteps#backfill_missing_generalized_geometries"
        )
        total_updated += updated
        Rails.logger.info("[ETL] backfill_missing_generalized_geometries: updated #{total_updated} row(s)") if updated.positive?
        break if updated < GENERALIZED_GEOMETRY_BACKFILL_BATCH_SIZE
      end

      analyze_spatial_tables if total_updated.positive?
      Rails.logger.info("[ETL] backfill_missing_generalized_geometries: complete, updated #{total_updated} row(s)")
    end

    # Join centroids to cartographic_states to assign the stusps code.
    def assign_state_codes(pwsids: nil)
      sql = <<~SQL
        UPDATE public_water_systems pws
        SET stusps = cs.stusps
        FROM service_area_geometries sag
        JOIN cartographic_states cs ON ST_Intersects(sag.centroid, cs.geom)
        WHERE pws.pwsid = sag.pwsid
          AND sag.centroid IS NOT NULL
      SQL
      sql << " AND pws.pwsid = ANY($1::text[])" if pwsids.present?

      updated = ApplicationRecord.connection.exec_update(sql, "PostImportSteps#assign_state_codes", pwsid_binds(pwsids))
      Rails.logger.info("[ETL] assign_state_codes: updated #{updated} row(s)")
    end

    # Rebuild the place_system_crosswalks table from spatial intersections.
    # Runs atomically: the table is either fully rebuilt or left untouched.
    #
    # Single-pass CTE: computes ST_Intersection once per pair, derives both
    # fractions from that result, and filters below-threshold pairs inline.
    # The explicit && bounding-box pre-filter ensures the GiST index is used.
    # Must run after rebuild_spatial_indexes so the index is fresh.
    def build_place_crosswalks(pwsids: nil)
      ApplicationRecord.connection.transaction do
        affected_geoids = []
        if pwsids.present?
          affected_geoids.concat(
            PlaceSystemCrosswalk.where(pwsid: pwsids).distinct.pluck(:geoid)
          )
          ApplicationRecord.connection.exec_delete(
            "DELETE FROM place_system_crosswalks WHERE pwsid = ANY($1::text[])",
            "PostImportSteps#delete_place_crosswalks",
            pwsid_binds(pwsids)
          )
        else
          ApplicationRecord.connection.execute("DELETE FROM place_system_crosswalks")
        end

        sql = <<~SQL
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
            WHERE sag.geom IS NOT NULL
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
        sql.sub!("WHERE sag.geom IS NOT NULL", "WHERE sag.geom IS NOT NULL AND sag.pwsid = ANY($1::text[])") if pwsids.present?
        inserted = if pwsids.present?
          inserted_rows = ApplicationRecord.connection.exec_query(
            "#{sql} RETURNING geoid",
            "PostImportSteps#build_place_crosswalks",
            pwsid_binds(pwsids)
          )
          affected_geoids.concat(inserted_rows.rows.flatten)
          inserted_rows.rows.size
        else
          ApplicationRecord.connection.execute(sql).cmd_tuples
        end

        Rails.logger.info("[ETL] build_place_crosswalks: inserted #{inserted} crosswalk(s)")
        affected_geoids.compact.uniq
      end
    end

    # Truncate the tile_cache table so stale MVT tiles are regenerated on
    # the next request. Called by Etl::Importer after any successful import
    # (not just geometry) because tiles embed non-geometry attributes.
    def bust_tile_cache
      deleted = TileCache.delete_all
      Rails.logger.info("[ETL] bust_tile_cache: deleted #{deleted} cached tile(s)")
    end

    def bust_cartographic_boundary_tile_cache
      deleted = TileCache.where(layer: %w[states counties places]).delete_all
      Rails.logger.info("[ETL] bust_cartographic_boundary_tile_cache: deleted #{deleted} cached boundary tile(s)")
    end

    # Rebuild GiST spatial indexes and update query-planner statistics after
    # a bulk geometry import. CONCURRENTLY avoids ACCESS EXCLUSIVE locks on
    # service_area_geometries while map requests continue using the old indexes.
    def rebuild_spatial_indexes
      conn = ApplicationRecord.connection
      conn.execute("REINDEX INDEX CONCURRENTLY index_service_area_geometries_on_geom")
      conn.execute("REINDEX INDEX CONCURRENTLY index_service_area_geometries_on_centroid")
      analyze_spatial_tables
      Rails.logger.info("[ETL] rebuild_spatial_indexes: complete")
    end

    def analyze_spatial_tables
      conn = ApplicationRecord.connection
      conn.execute("ANALYZE service_area_geometries")
      Rails.logger.info("[ETL] analyze_spatial_tables: complete")
    end

    def pwsid_binds(pwsids)
      return [] if pwsids.blank?

      [
        ActiveRecord::Relation::QueryAttribute.new(
          "pwsids",
          Array(pwsids).compact.uniq,
          pwsid_array_type
        )
      ]
    end

    def pwsid_array_type
      ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(ActiveModel::Type::String.new)
    end
  end
end
