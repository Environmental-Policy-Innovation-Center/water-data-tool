# ETL Pipeline

> How data flows from S3 into the database. Replaces the legacy Python `scheduled_data_import.py` with a Ruby Rake task / SolidQueue job.

---

## Overview

```
S3 Bucket (your-data-bucket)
  └── data.json manifest
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
        ├── pwsid_npdes_usts_rmps_imp.csv
        └── ...
              ↓
        Rake task / SolidQueue job
              ↓
        PostgreSQL (new schema with proper types)
```

The data publisher updates CSV/GeoJSON files in the configured source bucket and updates the `data.json` manifest with new `last_updated` timestamps. The ETL pipeline polls this manifest and imports any files that have changed.

---

## S3 Manifest (`data.json`)

The manifest is a JSON array of source file descriptors:

```json
[
  {
    "file_description": "EPA SABs geojson",
    "s3_path": "s3://your-data-bucket/national-dw-tool/path/epa_sabs_geoms.geojson",
    "http_path": "https://your-data-bucket.s3.us-east-1.amazonaws.com/national-dw-tool/path/epa_sabs_geoms.geojson",
    "last_updated": "2026-02-20 14:00:00"
  }
]
```

Use organization-specific values for `s3_path`, `http_path`, and bucket/region settings when transferring ownership.

| Field | Purpose |
|-------|---------|
| `file_description` | Human-readable label |
| `s3_path` | S3 URI (for reference — not used by ETL directly) |
| `http_path` | Public HTTPS URL used to download the file |
| `last_updated` | Timestamp of the last data update (compared against `data_imports` table) |

### Source Files

| File | Target Model | Format | Notes |
|------|-------------|--------|-------|
| `epa_sabs_geoms.geojson` | `ServiceAreaGeometry` | GeoJSON | MultiPolygon service area boundaries |
| `epa_sabs.csv` | `PublicWaterSystem` (partial) | CSV | Core PWS attributes |
| `sdwis_viols.csv` | `PublicWaterSystem` (partial) + `ViolationsSummary` | CSV | Attributes split between two models |
| `epa_sabs_xwalk.csv` | `Demographic` | CSV | ACS census crosswalk |
| `xwalk_pct_change_10yr.csv` | `TrendDatum` | CSV | 10yr demographic changes |
| `cejst.csv` | `EnvironmentalJustice` (partial) | CSV | CEJST indicators |
| `ejscreen.csv` | `EnvironmentalJustice` (partial) | CSV | EJScreen indicators |
| `svi.csv` | `EnvironmentalJustice` (partial) | CSV | Social Vulnerability Index |
| `cvi.csv` | `EnvironmentalJustice` (partial) | CSV | Climate Vulnerability Index |
| `national_bwn_highlevel_summary.csv` | `BoilWaterSummary` | CSV | Boil water notice history |
| `pwsid_funded_highlevel_summary.csv` | `FundingSummary` | CSV | SRF funding summaries |
| `pwsid_npdes_usts_rmps_imp.csv` | `WatershedHazard` | CSV | Watershed hazards (aggregated at import) |

---

## Import Flow

### Step 1: Fetch manifest

Download `data.json` from the S3 HTTP URL and parse it.

### Step 2: Compare timestamps

For each file in the manifest, compare its `last_updated` against the most recent `imported_at` for that `file_url` in the `data_imports` table. Skip files that haven't changed.

### Step 3: Download and import changed files

For each file that needs updating:

1. Download the file to a temp directory
2. Parse (CSV or GeoJSON)
3. Import into a **staging table** (temporary table with the new schema's column names and types)
4. Validate row counts and data integrity
5. Swap: drop the old table data and replace with staging data (within a transaction)
6. Record the import in `data_imports`

### Step 4: Run post-import steps

If `epa_sabs_geoms.geojson` was imported (geometry data changed), run the derived data steps. See "Post-Import Steps" below.

### Step 5: Invalidate tile cache

Truncate the `tile_cache` table (if all source tables changed) or delete specific layers (if only some tables changed).

---

## Type Casting Rules

The legacy ETL imports everything as TEXT. The new ETL casts at import time:

| Source Pattern | Target Type | Rule |
|---------------|------------|------|
| Numeric strings (`"42"`, `"1250000"`) | `integer` | `value.to_i` (NULL if blank or `"NA"`) |
| Decimal strings (`"0.85"`, `"12.3"`) | `decimal` | `value.to_d` (NULL if blank or `"NA"`) |
| `"Y"` / `"N"` indicators | `boolean` | `value == "Y"` |
| 0-to-1 scores | `decimal` (×100) | `(value.to_f * 100).round(2)` — applies to `a_int_identified_as_disadvantaged`, `pw_int_pop_rpl_themes`, `a_int_overall_cvi_score` |
| `"NA"` | `NULL` | All columns — legacy ETL already does this |
| Empty strings | `NULL` | Treat as missing data |
| Date-like strings | `string` | Keep as-is (date formats vary by state for BWN data) |

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

**`sdwis_viols.csv`** — this single CSV feeds two models:
- Attribute columns (`gw_sw_code`, `owner_type`, `primacy_type`, etc.) → `public_water_systems`
- Violation count columns → `violations_summaries`
- Boolean indicators (`is_wholesaler_ind`, etc.) need `"Y"`/`"N"` → `true`/`false` conversion

**`pwsid_npdes_usts_rmps_imp.csv`** — has multiple rows per PWS (one per HUC12 watershed). Pre-aggregate with `GROUP BY pwsid, SUM(...)` during import to produce one row per PWS for `watershed_hazards`.

**Environmental justice CSVs** (`cejst.csv`, `ejscreen.csv`, `svi.csv`, `cvi.csv`) — four separate files that all feed into the single `environmental_justices` table. Import each file's columns and merge on `pwsid`.

---

## Post-Import Steps

These run after `epa_sabs_geoms.geojson` is imported. They generate derived spatial data. Equivalent to the legacy `post_import_scripts.sql`.

### 1. Fix invalid geometries

```sql
UPDATE service_area_geometries
SET geom = ST_Buffer(geom, 0)
WHERE ST_IsValid(geom) = false;
```

Run repeatedly until 0 rows are updated.

### 2. Generate centroids

```sql
UPDATE service_area_geometries
SET centroid = ST_PointOnSurface(geom);
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

### 4. Build county associations

```sql
UPDATE public_water_systems pws
SET counties = sub.counties
FROM (
  SELECT sag.pwsid,
         array_to_string(array_agg(cc.namelsad || ', ' || cc.stusps), '; ') AS counties
  FROM cartographic_counties cc
  JOIN service_area_geometries sag ON ST_Intersects(sag.geom, cc.geom)
  WHERE GeometryType(ST_Intersection(sag.geom, cc.geom)) IN ('POLYGON', 'MULTIPOLYGON')
  GROUP BY sag.pwsid
) sub
WHERE pws.pwsid = sub.pwsid;
```

### 5. Build place crosswalks

```sql
-- Insert all intersecting place-system pairs
INSERT INTO place_system_crosswalks (geoid, pwsid)
SELECT cp.geoid, sag.pwsid
FROM cartographic_places cp
JOIN service_area_geometries sag ON ST_Intersects(sag.geom, cp.geom);

-- Calculate fractional overlaps
UPDATE place_system_crosswalks psc
SET fraction_of_service_area = ST_Area(ST_Intersection(sag.geom, cp.geom)) / ST_Area(sag.geom),
    fraction_of_place = ST_Area(ST_Intersection(sag.geom, cp.geom)) / ST_Area(cp.geom)
FROM service_area_geometries sag
JOIN cartographic_places cp ON ST_Intersects(sag.geom, cp.geom)
WHERE psc.pwsid = sag.pwsid AND psc.geoid = cp.geoid;

-- Remove noise (tiny overlaps at polygon edges)
DELETE FROM place_system_crosswalks
WHERE fraction_of_service_area < 0.01 OR fraction_of_place < 0.01;
```

### 6. Rebuild indexes

Recreate GiST spatial indexes on `service_area_geometries` and cluster the table on the spatial index for query performance.

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
etl_import:
  class: EtlImportJob
  schedule: every day at 6am
```

The job checks the manifest and only imports files with updated timestamps — safe to run frequently.

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| S3 unreachable | Log error, skip import, retry on next scheduled run |
| Malformed CSV row | Log warning with row number and file, skip row, continue import |
| Invalid geometry | Logged during post-import repair step; `ST_Buffer(geom, 0)` fixes most cases |
| Import fails mid-transaction | Transaction rolls back — old data remains intact |
| Duplicate `pwsid` in source | Last row wins (UPSERT / `ON CONFLICT UPDATE`) |

All import activity is logged with: file URL, row count imported, duration, errors encountered.

---

## Security Improvements over Legacy

| Issue | Legacy (Python) | New (Rails) |
|-------|----------------|-------------|
| SQL injection | f-string query building | Parameterized queries via ActiveRecord |
| Credentials | Flat `credentials.py` file | Rails encrypted credentials (`bin/rails credentials:edit`) or environment variables |
| S3 access | HTTP public URLs | IAM roles (preferred) or env var credentials |
| Schema isolation | Schema name in f-strings | Rails environments (`development` / `staging` / `production`) |
