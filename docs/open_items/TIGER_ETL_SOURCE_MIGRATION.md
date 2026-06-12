# TIGER Shapefile Source Migration (Census → S3)

## Context

### What
The current ETL downloads Census TIGER shapefiles directly from Census.gov URLs at runtime
(`CartographicBoundaries::LAYERS` in `app/services/cartographic_boundaries.rb`). The EPIC
data team has re-hosted the same TIGER zip archives in S3. This migration is simply changing
where we pull those files from — the file format, ogr2ogr machinery, staging table swap, and
post-import SQL steps all remain unchanged.

### Why
Removes a runtime dependency on an external Census.gov URL. If Census.gov changes paths or
goes down during an ETL run, `CartographicBoundaries.load` fails silently and spatial features
(county filter, map tiles) stop working. Hosting in S3 keeps all ETL source data under our
control. See `ETL_DEPLOY_INVESTIGATION.md` for the broader context.

---

## Implementation Guide

### All Three TIGER Files Are Still Needed

`sabs_pwsid_county.csv` (already in the ETL) populates the denormalized `counties` text column
on `PublicWaterSystem` for display purposes. But `cartographic_counties` (with actual polygon
geometries) is still required for:

- `tile_generator.rb:141` — county boundaries rendered in map tiles
- `filterable.rb:226` — county spatial filter uses `ST_Intersects` against county geometries

All three TIGER zip files must remain in S3 and in `CartographicBoundaries::LAYERS`.

### Current Source URLs (to be replaced)

In `app/services/cartographic_boundaries.rb`, lines ~6–27:

```ruby
LAYERS = [
  { zip_url: "https://www2.census.gov/geo/tiger/GENZ2022/shp/cb_2022_us_state_500k.zip", ... },
  { zip_url: "https://www2.census.gov/geo/tiger/GENZ2022/shp/cb_2022_us_county_500k.zip", ... },
  { zip_url: "https://www2.census.gov/geo/tiger/GENZ2022/shp/cb_2022_us_place_500k.zip", ... }
]
```

Confirm the exact S3 paths with the EPIC data team or by listing the bucket:

```bash
aws s3 ls s3://tech-team-data/national-dw-tool/ --profile thrive-epic
```

### What Changes

**1. Update `LAYERS` URLs** — replace the three `zip_url` values with the S3 HTTPS URLs.
The rest of `cartographic_boundaries.rb` is unchanged.

**2. Clear the zip cache** — `CartographicBoundaries` caches downloaded zips in
`tmp/cartographic/` and skips re-downloading if the zip already exists on disk. Clear this
after updating the URLs so the new S3 zips are fetched fresh:

```bash
rm -rf tmp/cartographic/
```

### Remove the Stale `loaded?` Guard

> **This fix is independent of the S3 URL migration and should be done first** — it is
> Priority 1 in the investigation plan and does not require the EPIC data team's S3 paths.

In `app/services/etl/post_import_steps.rb`:

```ruby
# current — buggy: skips reload when a new TIGER year is uploaded to S3
CartographicBoundaries.load unless CartographicBoundaries.loaded?

# fix — always reload when epa_sabs_geoms was imported
CartographicBoundaries.load
```

The guard was intended as a performance optimization (avoid reloading yearly-stable data on
every ETL run). But it only checks row presence — it cannot detect when files in S3 are updated
with a new TIGER year. The outer check that gates this entire block (`imported_files.include?("epa_sabs_geoms")`)
already correctly ensures we only reach this code when there is genuinely new geometry data.
The `loaded?` guard adds nothing and actively prevents refreshing cartographic data on a TIGER
year update. Remove it.

---

## Checklists

### Part 1 — Standalone fix (do this now, no external dependencies)

- [ ] Remove `loaded?` guard in `app/services/etl/post_import_steps.rb`
- [ ] Run `bin/ci` — all specs green

### Part 2 — S3 URL migration (blocked on EPIC data team confirming S3 paths)

- [ ] Confirm S3 paths for all three zip files (states, counties, places)
- [ ] Update `LAYERS` zip URLs in `app/services/cartographic_boundaries.rb`
- [ ] Clear `tmp/cartographic/` to force fresh downloads
- [ ] Run ETL locally with `bin/rails etl:import` and confirm cartographic tables populate
- [ ] Confirm `assign_state_codes` and `build_place_crosswalks` produce correct row counts in log output
- [ ] Run `bin/ci` — all specs green

---

> **Cleanup:** Delete this file when both checklists are complete. Reference the closing PR in the commit message.
