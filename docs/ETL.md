# ETL Pipeline

> How data flows from S3 into the database. Replaces the legacy Python `scheduled_data_import.py` with a Ruby Rake task / SolidQueue job.

---

## Overview

```
S3 Bucket (ETL_SOURCE_URL)
        ├── epa_sabs_geoms.geojson
        ├── epa_sabs.csv
        ├── sdwis_viols.csv
        ├── epa_sabs_xwalk.csv
        ├── xwalk_pct_change_10yr.csv
        ├── cejst.csv
        ├── ejscreen.csv
        ├── svi.csv
        ├── cvi.csv
        ├── national_bwn_highlevel_summary.csv
        ├── pwsid_funded_highlevel_summary.csv
        └── pwsid_npdes_usts_rmps_imp.csv
              ↓ HTTP HEAD per file (reads Last-Modified header)
        Rake task / SolidQueue job
              ↓
        PostgreSQL (new schema with proper types)
```

The data publisher overwrites files in place at the same S3 keys. The ETL issues an HTTP HEAD request per file, reads the `Last-Modified` header, and imports any files whose timestamp is newer than the last recorded import in the `data_imports` table. No manifest file is needed.

There is no per-environment S3 bucket — a single bucket serves development, staging, and production. The `ETL_SOURCE_URL` env var controls which folder path each environment reads from. Staging should point at the S3 `staging` folder, and production should point at the S3 `prod` folder.

---

## Source Files


| File                                 | Target Model                                        | Format  | Notes                                    |
| ------------------------------------ | --------------------------------------------------- | ------- | ---------------------------------------- |
| `epa_sabs_geoms.geojson`             | `ServiceAreaGeometry`                               | GeoJSON | MultiPolygon service area boundaries     |
| `epa_sabs.csv`                       | `PublicWaterSystem` (partial)                       | CSV     | Core PWS attributes                      |
| `sdwis_viols.csv`                    | `PublicWaterSystem` (partial) + `ViolationsSummary` | CSV     | Attributes split between two models      |
| `epa_sabs_xwalk.csv`                 | `Demographic`                                       | CSV     | ACS census crosswalk                     |
| `xwalk_pct_change_10yr.csv`          | `TrendDatum`                                        | CSV     | 10yr demographic changes                 |
| `cejst.csv`                          | `EnvironmentalJustice` (partial)                    | CSV     | CEJST indicators                         |
| `ejscreen.csv`                       | `EnvironmentalJustice` (partial)                    | CSV     | EJScreen indicators                      |
| `svi.csv`                            | `EnvironmentalJustice` (partial)                    | CSV     | Social Vulnerability Index               |
| `cvi.csv`                            | `EnvironmentalJustice` (partial)                    | CSV     | Climate Vulnerability Index              |
| `national_bwn_highlevel_summary.csv` | `BoilWaterSummary`                                  | CSV     | Boil water notice history                |
| `pwsid_funded_highlevel_summary.csv` | `FundingSummary`                                    | CSV     | SRF funding summaries                    |
| `pwsid_npdes_usts_rmps_imp.csv`      | `WatershedHazard`                                   | CSV     | Watershed hazards (aggregated at import) |


---

## Import Flow

### Step 1: Check freshness via HTTP HEAD

For each file key in `Etl::Importer::FILE_IMPORTERS`, issue an HTTP HEAD request to `ETL_SOURCE_URL/<key><ext>` and read the `Last-Modified` response header.

### Step 2: Compare timestamps

Compare each file's `Last-Modified` against the most recent `imported_at` for that URL in the `data_imports` table. Skip files that haven't changed.

### Step 3: Download and import changed files

For each file that needs updating:

1. Download the file (streamed to disk for large files — see below)
2. Parse (CSV or GeoJSON)
3. Validate row counts and data integrity
4. Upsert into the live table (`ON CONFLICT UPDATE`)
5. Record the import in `data_imports`

**Large file handling**: `epa_sabs_geoms.geojson` is ~1 GB and is handled differently from CSVs. It is streamed to a tempfile via chunked HTTP download (`Net::HTTP` block form), then SAX-parsed one feature at a time using `Oj::Saj`. Features are inserted in 500-record batches and the batch is cleared after each insert, keeping peak memory at O(batch_size) rather than O(file_size). This prevents OOM kills in the 1700 MB container.

### Step 4: Run post-import steps

Importers return `Etl::ImportResult` metadata describing skipped/imported status, changed PWS IDs, changed map layers, geometry changes, previous geometry bounds, and whether a full refresh is required.

If `epa_sabs_geoms.geojson` changed geometry rows, run the derived spatial steps for those systems where possible. See "Post-Import Steps" below.

### Step 5: Refresh affected tiles

For normal imports, do not truncate the full `tile_cache` table. `TileImpact` converts changed PWS/place bounds into affected z5-z8 tile coordinates with a one-tile edge margin, then enqueues small `TileCacheRefreshJob` batches on the `tile_refresh` queue. Those jobs overwrite affected cached rows; old rows remain readable until replacements are generated.

If an import result explicitly requires a full refresh, the legacy full cache bust plus `TileCacheWarmJob` path is used as a maintenance fallback.

---

## Type Casting Rules

The legacy ETL imports everything as TEXT. The new ETL casts at import time via helpers in `Etl::TypeCaster`:


| Helper        | Source columns                                                                                          | DB type          | Behavior                                                                                                                                                 |
| ------------- | ------------------------------------------------------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cast_int`    | Numeric strings (`"42"`, `"1250000"`)                                                                   | `integer`        | `nil` if blank, `nil`/`NULL`, or `"NA"` (case-insensitive)                                                                                               |
| `cast_dec`    | Decimal strings (`"0.85"`, `"12.3"`)                                                                    | `decimal`        | `nil` if blank, `nil`/`NULL`, or `"NA"`                                                                                                                  |
| `cast_score`  | 0-to-1 floats (`a_int_identified_as_disadvantaged`, `pw_int_pop_rpl_themes`, `a_int_overall_cvi_score`) | `decimal` (×100) | `(value.to_f * 100).round(2)`, `nil` if blank or `"NA"`                                                                                                  |
| `cast_bool`   | `"Yes"`/`"No"` or `"Y"`/`"N"` indicators                                                                | `boolean`        | `true` if `Y`/`YES`, `false` otherwise, `nil` if blank                                                                                                   |
| `cast_string` | Free-text / categorical string columns                                                                  | `string`         | Strips whitespace; `nil` if blank or `"NA"`. Real values (`"Territory"`, `"State"`, `"Tribal"`, `"Surface Water"`, `"No"`, etc.) pass through unchanged. |


**"NA" is a missing-value sentinel in the source CSVs** (a common convention in R/pandas pipelines). All five helpers normalize it to `NULL` in the database. No raw `"NA"` strings are stored.

> **Open question — descriptive sentinel strings:** Some CSV columns contain longer explanatory strings instead of `"NA"` for missing data (e.g. `most_common_rate_tidy` uses `"No Information on annual water & sewer rates"`). These are not currently normalized and are stored as-is. Confirm with the EPIC data team whether these strings should be displayed to users or suppressed in favour of a `NULL` / "No data" display.

### Column Name Mapping

The ETL must map legacy CSV column headers to new schema column names. The mapping is defined in TRANSITION.md. Example:

```ruby
# Mapping for epa_sabs.csv → public_water_systems
COLUMN_MAP = {
  "epic_area_mi2" => { column: "area_sq_miles", type: :decimal },
  "population_served_count" => { column: "population_served_count", type: :integer },
  "service_connections_count" => { column: "service_connections_count", type: :integer },
  # ...
}
```

### Special Cases

`**sdwis_viols.csv**` — this single CSV feeds two models:

- Attribute columns (`gw_sw_code`, `owner_type`, `primacy_type`, etc.) → `public_water_systems`
- Violation count columns → `violations_summaries`
- Boolean indicators (`is_wholesaler_ind`, etc.) use `"Yes"`/`"No"` in the source — cast via `Etl::TypeCaster#cast_bool`

`**pwsid_npdes_usts_rmps_imp.csv**` — has multiple rows per PWS (one per HUC12 watershed). Pre-aggregate with `GROUP BY pwsid, SUM(...)` during import to produce one row per PWS for `watershed_hazards`.

**Environmental justice CSVs** (`cejst.csv`, `ejscreen.csv`, `svi.csv`, `cvi.csv`) — four separate files that all feed into the single `environmental_justices` table. Import each file's columns and merge on `pwsid`.

---

## Post-Import Steps

These run after changed geometries are imported. They generate derived spatial data equivalent to the legacy `post_import_scripts.sql`, but normal runs scope work to changed `pwsid`s where possible.

### 1. Fix invalid geometries

```sql
UPDATE service_area_geometries
SET geom = ST_Buffer(geom, 0)
WHERE ST_IsValid(geom) = false
  AND pwsid = ANY($1::text[]);
```

Run repeatedly until 0 rows are updated. Full refresh fallbacks can run the same repair globally.

### 2. Generate centroids

```sql
UPDATE service_area_geometries
SET centroid = ST_PointOnSurface(geom)
WHERE pwsid = ANY($1::text[]);
```

Uses `ST_PointOnSurface` (not `ST_Centroid`) to guarantee the point falls within the polygon.

### 3. Assign state codes

```sql
UPDATE public_water_systems pws
SET stusps = cs.stusps
FROM service_area_geometries sag
JOIN cartographic_states cs ON ST_Intersects(sag.centroid, cs.geom)
WHERE pws.pwsid = sag.pwsid;
```

Scoped runs also add `AND pws.pwsid = ANY($1::text[])`.

### 4. Build place crosswalks

```sql
DELETE FROM place_system_crosswalks
WHERE pwsid = ANY($1::text[]);

WITH intersections AS (
  SELECT
    cp.geoid,
    sag.pwsid,
    ST_Intersection(sag.geom, cp.geom) AS ix_geom,
    ST_Area(sag.geom) AS sag_area,
    ST_Area(cp.geom) AS place_area
  FROM cartographic_places cp
  JOIN service_area_geometries sag
    ON sag.geom && cp.geom
   AND ST_Intersects(sag.geom, cp.geom)
  WHERE sag.geom IS NOT NULL
    AND sag.pwsid = ANY($1::text[])
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
WHERE ST_Area(ix_geom) / NULLIF(sag_area, 0) >= 0.01
   OR ST_Area(ix_geom) / NULLIF(place_area, 0) >= 0.01
ON CONFLICT (geoid, pwsid) DO NOTHING;
```

The method returns affected place geoids so place tiles can be refreshed along with PWS tiles.

### 5. Analyze spatial tables

Normal scoped imports run `ANALYZE service_area_geometries` so the planner sees updated geometry statistics. The full refresh fallback can still rebuild GiST indexes concurrently when a global geometry reload requires it.

---

## Running the ETL

### Manually

```bash
# Full import (all changed files)
bin/rails etl:import

# Single table
bin/rails etl:import[epa_sabs]

# Force re-import (ignore timestamps)
bin/rails etl:import[epa_sabs,force]
```

### Scheduled (SolidQueue)

Configure a recurring job in `config/recurring.yml`:

```yaml
production:
  # Rendered only when ETL_SCHEDULE_ENABLED=true
  etl_import:
    class: EtlImportJob
    queue: etl
    schedule: every day at 12am America/New_York
```

The job runs on the dedicated `etl` queue and has a concurrency limit so imports cannot overlap. It issues HEAD requests per file and only imports files with updated `Last-Modified` timestamps. If a source omits `Last-Modified`, the file imports as changed.

Because staging and production ECS services use `RAILS_ENV=production`, recurring ETL is gated by `ETL_SCHEDULE_ENABLED=true` rather than Rails environment alone. Leave the variable unset or false anywhere recurring imports should not run. Preview intentionally leaves it unset — its single ephemeral instance can be down or mid-redeploy at the scheduled time and the in-puma import can OOM the small container, so the nightly refresh runs decoupled as a dedicated ECS task via the `run-etl-preview.yml` GitHub Actions cron (see `DEPLOYMENTS.md`).

---

## Runtime, Downtime, and Known Issues

### Expected Duration

A full import that includes `epa_sabs_geoms.geojson` (the only file that triggers post-import
geometry steps) runs roughly as follows:

| Step | Estimate |
|---|---|
| Download + SAX-parse + batch insert `epa_sabs_geoms.geojson` (~1 GB) | 15–45 min |
| `CartographicBoundaries.load` — 3 TIGER zips via `ogr2ogr` | 5–15 min |
| `fix_invalid_geometries` + `generate_centroids` | 2–5 min |
| `assign_state_codes` + `build_place_crosswalks` (national spatial joins) | 10–30 min |
| `ANALYZE` on `service_area_geometries` | seconds to minutes |
| **Total** | **~35–105 min** |

CSV-only runs (no geometry change) complete in seconds to a few minutes and do not trigger
the steps above.

### Runtime Behavior During Imports

Imports are designed to keep Puma responsive while data refreshes:

- `EtlImportJob` runs on the dedicated single-thread `etl` queue.
- Tile refresh jobs run on the dedicated single-thread `tile_refresh` queue.
- Existing cached tiles stay readable during normal selective refreshes.
- Geometry-derived work is scoped to changed systems when import metadata can identify them.
- Full cache bust/warm remains available only for explicit full-refresh fallbacks.

If health checks still fail during a full national geometry refresh, the next operational step is a separate worker process or ECS service so ETL cannot compete with web requests in the same container.

---

## Error Handling


| Scenario                     | Behavior                                                                     |
| ---------------------------- | ---------------------------------------------------------------------------- |
| S3 unreachable               | Log error, skip import, retry on next scheduled run                          |
| Malformed CSV row            | Log warning with row number and file, skip row, continue import              |
| Invalid geometry             | Logged during post-import repair step; `ST_Buffer(geom, 0)` fixes most cases |
| Import fails mid-transaction | Transaction rolls back — old data remains intact                             |
| Duplicate `pwsid` in source  | Last row wins (UPSERT / `ON CONFLICT UPDATE`)                                |


All import activity is logged with: file URL, row count imported, duration, errors encountered.

---

## Security Improvements over Legacy


| Issue            | Legacy (Python)            | New (Rails)                                                                                 |
| ---------------- | -------------------------- | ------------------------------------------------------------------------------------------- |
| SQL injection    | f-string query building    | Parameterized queries via ActiveRecord                                                      |
| Credentials      | Flat `credentials.py` file | Rails encrypted credentials (`bin/rails credentials:edit`) or environment variables         |
| S3 access        | HTTP public URLs           | Public HTTPS — no credentials required for reads; IAM only needed if bucket is made private |
| Schema isolation | Schema name in f-strings   | Rails environments (`development` / `staging` / `production`)                               |
