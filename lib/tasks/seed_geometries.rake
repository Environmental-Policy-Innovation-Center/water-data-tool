# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc <<~DESC
      Seed fake service area geometries for development/testing.
      Generates small circular polygons at random points within each state's
      bounding box — useful for testing tile rendering without real ETL data.

      Usage:
        bin/rails db:seed:fake_geometries[VT,RI]
    DESC
    task :fake_geometries, [:states] => :environment do |_, args|
      abort "Usage: bin/rails db:seed:fake_geometries[VT,RI]" if args[:states].blank?

      states = ([args[:states]] + args.extras).compact.map(&:strip).map(&:upcase)

      # Approximate bounding boxes for supported states.
      # Polygons are generated as random points within these bounds.
      state_bounds = {
        "VT" => {min_lon: -73.45, max_lon: -71.46, min_lat: 42.72, max_lat: 45.02, statefp: "50", geoid: "50", gid: 50,
                 name: "Vermont"},
        "RI" => {min_lon: -71.91, max_lon: -71.09, min_lat: 41.14, max_lat: 42.02, statefp: "44", geoid: "44", gid: 44,
                 name: "Rhode Island"},
        "NH" => {min_lon: -72.56, max_lon: -70.70, min_lat: 42.69, max_lat: 45.31, statefp: "33", geoid: "33", gid: 33,
                 name: "New Hampshire"},
        "ME" => {min_lon: -71.08, max_lon: -66.95, min_lat: 42.98, max_lat: 47.46, statefp: "23", geoid: "23", gid: 23,
                 name: "Maine"},
        "MA" => {min_lon: -73.51, max_lon: -69.93, min_lat: 41.24, max_lat: 42.89, statefp: "25", geoid: "25", gid: 25,
                 name: "Massachusetts"}
      }.freeze

      unknown = states - state_bounds.keys
      abort "Unsupported state(s): #{unknown.join(", ")}. Supported: #{state_bounds.keys.join(", ")}" if unknown.any?

      conn = ApplicationRecord.connection

      states.each do |stusps|
        bounds = state_bounds[stusps]

        # ── 1. Seed cartographic_states with a simplified bounding box ──────────
        conn.execute(<<~SQL)
          INSERT INTO cartographic_states (gid, statefp, stusps, geoid, name, geom)
          VALUES (
            #{bounds[:gid]},
            #{conn.quote(bounds[:statefp])},
            #{conn.quote(stusps)},
            #{conn.quote(bounds[:geoid])},
            #{conn.quote(bounds[:name])},
            ST_GeomFromText(
              'MULTIPOLYGON(((
                #{bounds[:min_lon]} #{bounds[:min_lat]},
                #{bounds[:max_lon]} #{bounds[:min_lat]},
                #{bounds[:max_lon]} #{bounds[:max_lat]},
                #{bounds[:min_lon]} #{bounds[:max_lat]},
                #{bounds[:min_lon]} #{bounds[:min_lat]}
              )))',
              4326
            )
          )
          ON CONFLICT (gid) DO UPDATE SET
            stusps = EXCLUDED.stusps,
            geom   = EXCLUDED.geom
        SQL

        puts "  cartographic_states:  #{stusps} bounding box inserted"

        # ── 2. Generate fake service area polygons for each PWS ─────────────────
        # ST_Buffer on a geography type gives accurate km-radius circles.
        # We use ST_GeogFromText to buffer in meters, then cast back to geometry.
        # Radius is randomised between 2–15 km to simulate a variety of system sizes.
        pwsids = PublicWaterSystem.where(stusps: stusps).pluck(:pwsid)

        lon_range = bounds[:max_lon] - bounds[:min_lon]
        lat_range = bounds[:max_lat] - bounds[:min_lat]

        inserted = 0
        pwsids.each do |pwsid|
          # Deterministic pseudo-random point based on pwsid hash, so re-running
          # produces the same geometries.
          seed = pwsid.bytes.sum
          lon = (bounds[:min_lon] + (seed % 1000) / 1000.0 * lon_range).round(6)
          lat = (bounds[:min_lat] + ((seed / 7) % 1000) / 1000.0 * lat_range).round(6)
          radius_m = 2000 + (seed % 13_000) # 2–15 km

          conn.execute(<<~SQL)
            INSERT INTO service_area_geometries (pwsid, geom, created_at, updated_at)
            VALUES (
              #{conn.quote(pwsid)},
              ST_Multi(
                ST_Buffer(
                  ST_GeogFromText('POINT(#{lon} #{lat})')::geography,
                  #{radius_m}
                )::geometry
              ),
              NOW(), NOW()
            )
            ON CONFLICT (pwsid) DO UPDATE SET
              geom = EXCLUDED.geom,
              centroid = NULL
          SQL

          inserted += 1
        end

        puts "  service_area_geometries: #{inserted} fake polygon(s) for #{stusps}"
      end

      # ── 3. Run post-import steps to generate centroids, assign state codes ───
      puts "  Running PostImportSteps (centroids, state codes)..."
      Etl::PostImportSteps.generate_centroids
      Etl::PostImportSteps.assign_state_codes
      Etl::PostImportSteps.rebuild_spatial_indexes

      puts "✓ Done. Restart bin/dev then hard-refresh the browser."
    end
  end
end
