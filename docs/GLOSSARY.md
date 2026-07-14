# Glossary

Domain acronyms, data source names, field abbreviations, and technical terms used in this codebase. Cross-references point to the schema tables or models where terms appear.

---

## Acronyms & Field Abbreviations

| Term | Definition |
|------|-----------|
| **AIAN** | American Indian / Alaska Native — racial category in ACS data; see `demographics.aian_rate` |
| **BWN** | Boil Water Notice — advisory issued when tap water may be unsafe without boiling; see `boil_water_summaries` |
| **CEJST** | Climate and Economic Justice Screening Tool — White House tool identifying disadvantaged communities; see `environmental_justices.cejst_*` |
| **CVI** | Community Vulnerability Index — composite score covering redlining, life expectancy, and cancer risk; see `environmental_justices.cvi_*` |
| **EJScreen** | EPA Environmental Justice Screening and Mapping Tool — provides disability and drinking water non-compliance scores; see `environmental_justices.ejscreen_*` |
| **EWG** | Environmental Working Group — publishes public water quality reports; see `public_water_systems.ewg_report_link` |
| **FIPS** | Federal Information Processing Standards — numeric codes for U.S. states and counties; see `cartographic_counties.statefp`, `countyfp`, `geoid` |
| **GEOID** | Census geographic identifier — concatenated FIPS codes that uniquely identify a geographic unit. County GEOID = `statefp` (2) + `countyfp` (3). Place GEOID = `statefp` (2) + `placefp` (5). See `place_system_crosswalks.geoid` |
| **GID** | Geographic ID — auto-assigned integer primary key on cartographic tables (`cartographic_states`, `cartographic_counties`, `cartographic_places`) in place of the default `id` column |
| **GW** | Groundwater — water sourced from underground aquifers; one of the two values for `gw_sw_code` |
| **HUC12** | Hydrologic Unit Code (12-digit) — watershed boundary identifier used in source water protection analysis; referenced in ETL pipeline |
| **MHI** | Median Household Income; see `demographics.median_household_income` and `trend_data.mhi_pct_change` |
| **MVT** | Mapbox Vector Tile — protobuf binary tile format; stored in `tile_cache.mvt` and served by the vector tile endpoints |
| **NAPI** | Native Hawaiian / Pacific Islander — racial category in ACS data; see `demographics.napi_rate` |
| **NPDES** | National Pollutant Discharge Elimination System — EPA permit program for facilities that discharge pollutants into waterways; see `watershed_hazards.npdes_permits` |
| **POC** | People of Color — all non-white population; see `demographics.poc_rate` and `trend_data.poc_pct_change` |
| **pop\_cat\_5** | Population category (five tiers) — EPA classification bucketing systems by population served: Very Small (<500), Small (500–3,300), Medium (3,301–10,000), Large (10,001–100,000), Very Large (>100,000); see `public_water_systems.pop_cat_5` |
| **PWS** | Public Water System — any system providing piped water for human consumption to 15 or more connections or 25 or more people; the core entity of this application |
| **PWSID** | Public Water System Identifier — 9-character EPA string ID uniquely identifying each PWS. The dominant format is 2-letter state code + 7 digits (e.g., `VT0100013`), but several variants exist in the dataset (as of May 2026, ~44,600 total records): all-numeric tribal IDs assigned by EPA region (e.g., `084690440`; ~444 records), state-specific alphanumeric formats (Utah `UTAH01001`, Delaware `DE00A0159`, Washington `WA53AA101`; ~580 records), and a small set of North Dakota compound IDs where multiple system IDs are joined by `"; "` (e.g., `ND3401128; ND1001380; ND4801479`; 9 records). Primary key throughout the schema. Route constraint: `/[A-Z0-9;%]+/` |
| **RMP** | Risk Management Plan — EPA-required plan for facilities storing hazardous chemicals; see `watershed_hazards.risk_management_plan_facilities` |
| **SABS** | Service Area Boundaries — EPA polygon dataset delimiting each PWS's geographic service area; source table `epa_sabs` in ETL, maps to `service_area_geometries` |
| **SDWIS** | Safe Drinking Water Information System — EPA database of public water system attributes and violation records; primary ETL data source |
| **SRF** | State Revolving Fund — EPA/state low-interest loan program for drinking water infrastructure improvements; see `funding_summaries.total_srf_assistance` |
| **SRID** | Spatial Reference Identifier — numeric code identifying a coordinate reference system. 4326 = WGS 84 (lat/lng), 3857 = Web Mercator (tiles) |
| **STUSPS** | State USPS Abbreviation — 2-letter postal code (e.g., `VT`, `RI`); used as the state component of PWSID and as a filter/index field |
| **SVI** | Social Vulnerability Index — CDC composite index measuring community vulnerability to hazards; see `environmental_justices.svi_overall_pctl` |
| **SW** | Surface Water — water sourced from rivers, lakes, or reservoirs; one of the two values for `gw_sw_code` |
| **TIGER** | Topologically Integrated Geographic Encoding and Referencing — the U.S. Census Bureau geographic dataset. Our boundary layers load the Census **Cartographic Boundary** shapefiles (`us_state/county/place_500k`, a generalized form of TIGER/Line) into `cartographic_states/counties/places`; see Data Sources |
| **UST** | Underground Storage Tank — tracked by EPA for contamination risk; see `watershed_hazards.open_underground_storage_tanks` |
| **xwalk** | Crosswalk — a mapping table joining two datasets by a shared key. `place_system_crosswalks` maps Census places to PWS service areas with overlap fractions |

---

## Data Sources

| Source | Description |
|--------|-----------|
| **ACS** | American Community Survey — U.S. Census Bureau periodic demographic survey; source for `demographics` and `trend_data` |
| **Census TIGER** | U.S. Census Bureau boundary shapefiles — the 1:500k Cartographic Boundary Files for states, counties, and places; loaded via `ogr2ogr` into `cartographic_states/counties/places`, powering the `states`, `counties`, `places` map layers |
| **CEJST** | Climate and Economic Justice Screening Tool — White House Council on Environmental Quality; source for `environmental_justices.cejst_*` fields |
| **CVI** | Community Vulnerability Index — composite index from redlining, life expectancy, and cancer risk data; source for `environmental_justices.cvi_*` fields |
| **EPA EJScreen** | EPA Environmental Justice Screening Tool — provides disability and drinking water compliance scores; source for `environmental_justices.ejscreen_*` fields |
| **EPA SABS** | EPA Service Area Boundaries — GeoJSON polygon dataset for map rendering; ETL source table `epa_sabs`, stored in `service_area_geometries` |
| **EPA SDWIS** | Safe Drinking Water Information System — authoritative source for PWS attributes, violations, and boil water data; primary ETL input |
| **SRF** | State Revolving Fund loan database — source for `funding_summaries` |
| **CDC SVI** | CDC Social Vulnerability Index — census-tract composite scores; source for `environmental_justices.svi_overall_pctl` |

---

## Water System Classification Codes

| Field | Values & Meaning |
|-------|----------------|
| `gw_sw_code` | `"Groundwater"` / `"Surface Water"` — primary water source type |
| `owner_type` | `"Federal"`, `"State"`, `"Local Government"`, `"Native American"`, `"Private"`, `"Public/Private"` |
| `pop_cat_5` | `"Very Small"` (<500), `"Small"` (500–3,300), `"Medium"` (3,301–10,000), `"Large"` (10,001–100,000), `"Very Large"` (>100,000) |
| `primary_source_code` | EPA code for detailed water source type (e.g., `GW` = groundwater, `SW` = surface water, `GU` = groundwater under direct influence of surface water) |
| `primacy_type` | `"State"`, `"Tribal"`, `"Territory"` — type of regulatory authority overseeing the system |
| `primacy_agency` | Name of the state/tribal/territory agency with regulatory authority (SDWIS primacy) |
| `service_area_type` | `"System Sourced"` (boundary provided by the PWS) or `"Modeled"` (boundary estimated from census data) |
| `source_water_protection_code` | EPA indicator for whether the system has an active source water protection program |
| `open_health_viol` | `"Yes"` / `"No"` — whether the system currently has an open health-based violation |
| `symbology_field` | Derived field used to drive Mapbox layer styling and legend classification |

---

## Technical Terms

| Term | Definition |
|------|-----------|
| **GiST Index** | Generalized Search Tree — PostgreSQL index type used on geometry columns (`geom`, `centroid`) to enable fast spatial queries |
| **MVT** | See Mapbox Vector Tile above |
| **ogr2ogr** | GDAL command-line tool for converting between geospatial formats; the ETL uses it to load Census boundary shapefiles into PostGIS (`cartographic_*` tables) |
| **PostGIS** | PostgreSQL extension providing geometry data types (`multi_polygon`, `st_point`) and spatial functions (`ST_Transform`, `ST_PointOnSurface`, `ST_Buffer`) |
| **ST_Transform** | PostGIS function converting geometries between coordinate systems; used to reproject from EPSG:4326 (stored) to EPSG:3857 (tile rendering) |
| **Tile Cache** | `tile_cache` table — stores MVT protobuf binaries keyed by `(layer, z, x, y)`. Layers: `pws`, `places`, `counties`, `states`, plus `pws_low_poly_v1` (the low-zoom, z<5, simplified pws cache). See [TILE_CACHE.md](TILE_CACHE.md) for lifecycle, invalidation, and manual bust/warm workflows |
| **TileBBox** | PostGIS utility function converting tile coordinates `(z, x, y)` to a bounding box geometry for use in MVT generation queries |
| **WGS 84** | World Geodetic System 1984 — coordinate reference system (EPSG:4326) used to store all geometries in this database |
| **Web Mercator** | EPSG:3857 — projected coordinate system used by Mapbox GL JS for tile rendering; geometries are reprojected to this system at tile generation time |
