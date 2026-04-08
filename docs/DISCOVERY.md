# Drinking Water Explorer — Discovery & Transition Notes

> Reference document for the Rails 8 rewrite. Captures what the current app does, how it works, what's broken, and how the new version should be structured.

---

## What This App Is

The **Drinking Water Explorer** is a public-facing, read-only data visualization tool built for EPIC (Environmental Policy Innovation Center). It lets anyone explore public water systems (PWS) across the United States — filtering, mapping, and downloading data about water quality, violations, demographics, and funding.

There is no login. No user accounts. No write operations. It is purely a data exploration and download tool.

---

## User-Facing Features

| Feature | Description |
|---------|-------------|
| **Interactive map** | National map of PWS service area boundaries, rendered via Mapbox GL JS |
| **Filters** | Filter systems by source type, attributes, boundaries, compliance, population |
| **Filter groups** | Source, Attributes, Boundaries, Compliance, Population, More |
| **Geography search** | Mapbox geocoder to search/zoom to a location |
| **PWS detail** | Click a system on the map to see a detail panel / report |
| **Data table** | Tabular view of filtered systems with ~70 columns |
| **Export** | Download filtered results as CSV or GeoJSON |
| **Bulk downloads** | Pre-built zip downloads (national + per state) hosted on S3 |
| **Datasets section** | Describes the source datasets used |
| **Documentation** | Links to a methodology PDF hosted on S3 |
| **Last updated date** | Shown in sidebar, pulled live from DB |

---

## Current Stack

| Layer | Technology |
|-------|-----------|
| Web server | Apache 2.4 on EC2 (Ubuntu 22) |
| Backend | PHP 8.1 (procedural, no framework) |
| Frontend | jQuery, vanilla JS, Mapbox GL JS v3 |
| UI components | DataTables, Highcharts, Tippy.js, Isotope |
| Database | Aurora PostgreSQL 15 (PostGIS) — writer + read replica(s) |
| ETL | Python 3.10 (scheduled script) |
| Map tiles | Mapbox Vector Tiles (MVT) — generated server-side by PHP, cached in DB |
| Hosting | AWS EC2 + RDS |
| Data storage | AWS S3 (source CSVs/GeoJSONs) |

---

## How Data Flows

### Data In (ETL pipeline)
```
AWS S3 bucket (tech-team-data)
  └── data.json manifest (list of CSV/GeoJSON files + last_updated timestamps)
        └── scheduled_data_import.py (Python)
              └── Compares timestamps against file_import_tracker table
                    └── Downloads changed files → imports into PostgreSQL
```

14 source files are imported into separate tables, all keyed by `pwsid`:

| Table | Source | Contains |
|-------|--------|----------|
| `epa_sabs_geoms` | GeoJSON | PWS service area polygons |
| `epa_sabs` | CSV | Core PWS attributes (name, pop, type, connections) |
| `sdwis_viols` | CSV | Drinking water violations (5yr/10yr counts by rule) |
| `epa_sabs_xwalk` | CSV | ACS demographics (income, race, age, poverty, etc.) |
| `xwalk_pct_change_10yr` | CSV | 10yr trend deltas (2011–2021) |
| `cejst` | CSV | Climate/environmental justice scores |
| `ejscreen` | CSV | EPA EJScreen scores |
| `svi` | CSV | CDC Social Vulnerability Index |
| `cvi` | CSV | Climate Vulnerability Index |
| `national_bwn_highlevel_summary` | CSV | Boil water notice history |
| `pwsid_funded_highlevel_summary` | CSV | SRF funding summaries |
| `pwsid_npdes_usts_rmps_imp` | CSV | Watershed hazards (NPDES, USTs, 303d) |

Derived tables built after import: `epa_sabs_points` (centroids), `place_sabs_xtab`, `pws_counties`.

### Data Out (to browser)
```
Browser
  ├── GET wdt_mvt.php?z=&x=&y=  →  Binary MVT protobuf (map tiles, 11 layers)
  ├── POST download_geojson.php (pws_ids=...)  →  Gzipped GeoJSON FeatureCollection
  └── Client-side CSV export  →  DataTables dumps in-memory data to file
```

---

## The Core Performance Problem

The current app loads **the entire national dataset into the browser at once**:

1. On load, Mapbox fetches tiles for the full US viewport
2. JS calls `querySourceFeatures` across 11 tile layers, merging results into one `mergedData` object (~tens of thousands of features, ~70 properties each)
3. Every filter change iterates all of `mergedData` in JS — no new server request, just O(n) scans
4. The table, export, and map all use this same in-memory object

**Result:** 5+ second initial load, 5–10+ second filter changes, no scalability headroom.

**Fix:** Move filter logic to the server. A filter API endpoint runs SQL and returns only matching PWS. The client never holds the full national set.

---

## External Services & Dependencies

| Service | Role | Account owner |
|---------|------|---------------|
| **Mapbox** | Map rendering, geocoder, tile display | Needs transfer to EPIC |
| **AWS S3** | Source data files + bulk download zips | Needs transfer to EPIC |
| **AWS EC2** | Web server | Needs transfer to EPIC |
| **AWS RDS** | PostgreSQL database | Needs transfer to EPIC |
| **Google Analytics** | Usage tracking | Needs transfer to EPIC |
| **Google Fonts** | Public Sans typeface | Public CDN, no account needed |

---

## Things to Be Aware Of

### Security issues in current code
- **SQL injection surface** — Python ETL builds queries with f-strings. No parameterized queries.
- **Credentials in flat files** — DB credentials in `dbFunctions.inc.php`, gitignored but still a flat PHP file pattern
- **Mapbox token in JS** — currently uses a public dev token; needs a URL-restricted token in production

### Architecture issues
- All filter logic lives only in client-side JS — can't reuse for API, export, or mobile without duplicating
- `mergedData` is populated once on load; pan/zoom loads new tiles but never updates it, so table counts can be stale vs. what's visible on screen
- No pagination anywhere — all-or-nothing loads
- No tests of any kind

### Local development
- Currently: developers add their IP to the RDS security group and connect directly to the staging database. No local DB.
- This is fragile (IP changes break it) and risky (everyone's pointed at shared staging data)
- The rewrite should use a local PostgreSQL instance seeded with a representative data subset

---

## Target Architecture (Rails 8)

### Stack decisions (from design_notes.md)

| Layer | Choice |
|-------|--------|
| Backend framework | Rails 8 |
| Frontend | Hotwire (Turbo + Stimulus) + Tailwind CSS |
| Auth | Devise + Pundit |
| Background jobs | SolidQueue |
| Database | PostgreSQL (with PostGIS) |
| Map | Mapbox GL JS (retained — no viable drop-in replacement) |
| Hosting | AWS (EC2 + RDS, migrated to EPIC's account) |

### How the rewrite addresses current problems

**ETL:** Replace Python `scheduled_data_import.py` with a Rake task (or SolidQueue job). Same logic, one language, one codebase. Parameterized queries fix the SQL injection issue.

**Filter API:** Add a `GET /public_water_systems` endpoint that accepts filter params and runs them in SQL. Returns only matching PWS as JSON/GeoJSON. This is the single biggest performance win — server filters, bounded response, no client-side merge of 70k features.

**Map tiles:** `wdt_mvt.php` is a tile server — it accepts `z/x/y` params, generates MVT tiles via PostGIS (`ST_AsMVT`), caches them in the `wdt_mvt` table, and returns binary protobuf. This logic moves to a Rails controller action. The caching pattern is worth keeping.

**Frontend:** Hotwire replaces the jQuery soup. Filter interactions trigger Turbo Frame/Stream updates. The map (Mapbox GL JS) stays as a Stimulus controller. DataTables can be replaced with a simpler server-rendered table with Turbo pagination.

**Local dev:** Docker Compose with a local Postgres + PostGIS container. Seed data from one or two states (available as pre-built zip downloads on S3). No RDS dependency for day-to-day development.

### Rough model shape

```
PublicWaterSystem
  pwsid (PK), pws_name, stusps, primacy_agency
  pop_cat_5, population_served_count, service_connections_count
  service_area_type, gw_sw_code, primary_source_code
  owner_type, primacy_type, years_operating
  is_wholesaler_ind, is_school_or_daycare_ind
  is_grant_eligible_ind, source_water_protection_code
  symbology_field, open_health_viol, ...

  has_one :service_area_geometry    (PostGIS polygon)
  has_one :demographics             (ACS crosswalk data)
  has_one :violations_summary       (SDWIS violations)
  has_one :environmental_justice    (CEJST, EJScreen, SVI, CVI)
  has_one :funding_summary          (SRF funding)
  has_one :watershed_hazards        (NPDES, USTs, 303d)
  has_one :boil_water_summary       (BWN history)
  has_one :trend_data               (10yr % changes)
```

### Key routes

```
GET  /                              → map view (main entry point)
GET  /public_water_systems          → filtered JSON (filter API)
GET  /public_water_systems/:pwsid   → single system detail
GET  /public_water_systems/:pwsid/report → printable report
GET  /public_water_systems/export   → CSV/GeoJSON download
GET  /tiles/:z/:x/:y                → MVT tile endpoint
GET  /datasets                      → datasets info page
GET  /downloads                     → bulk downloads page
```

---

## Open Questions

- Does this app need auth at all, or is it fully public? (Current app: no auth)
- Who triggers ETL runs — a cron? Manual? On data publish?
- Does S3 stay as the source-of-truth for raw data, or does EPIC want the pipeline to pull from somewhere else?
- Is there an admin interface needed (ActiveAdmin?) or is data management purely via ETL?
- What does the CNT Mapbox style look like — do we recreate it or use a default Mapbox style?
- Sample/seed data: can we use one of the state zip downloads from S3 to bootstrap local dev?

---

## Questions for CNT Handoff Meeting

- How do you run this locally — what does your Docker setup look like?
- What were the trickiest parts to build?
- Any design materials / Figma files?
- What does the CSV data look like before it hits S3? Who produces it?
- Which accounts/logins are CNT's vs. EPIC's (Mapbox, Google Analytics, AWS)?
- What should we know that isn't documented?

