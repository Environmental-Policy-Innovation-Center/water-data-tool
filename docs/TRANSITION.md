# Transition Plan: PHP to Rails 8

> Maps every table and column from the legacy PHP app to the new Rails schema. Serves as the definitive reference for "where did X go?" during the rewrite.

---

## Migration Philosophy

The legacy app stores **everything as TEXT** — population counts, percentages, booleans, dates. The Python ETL creates columns dynamically from CSV headers and never casts types. The Rails schema corrects this with proper column types, Rails naming conventions, and explicit foreign keys.

This is a **one-time schema translation**, not an ongoing sync. Once the Rails app is running, the ETL pipeline imports source CSVs directly into the new schema with type casting at import time.

---

## Infrastructure Assumptions

- **New AWS account:** The Rails app is expected to be deployed into the recipient organization's AWS account (fresh EC2/ECS host and fresh RDS database). This is not a migration of existing infrastructure.
- **Configurable data source:** The ETL source location (manifest URL, bucket, and path conventions) should be treated as environment-specific and updated during handoff.
- **No database migration:** We are not migrating data from the old database. The new database will be populated from scratch via the ETL pipeline (pulling from S3). The old database may be decommissioned once the new app is verified.
- **Cartographic boundaries:** The static reference tables (`cartographic_states`, `cartographic_counties`, `cartographic_places`) will need to be loaded into the new database. These can be exported from the old DB or sourced from Census directly.

---

## Table Mapping

| Legacy Table | New Model | New Table | Notes |
|-------------|-----------|-----------|-------|
| `epa_sabs` | `PublicWaterSystem` | `public_water_systems` | Core attributes |
| `sdwis_viols` (attribute columns) | `PublicWaterSystem` | `public_water_systems` | Non-violation columns moved here |
| `sdwis_viols` (violation columns) | `ViolationsSummary` | `violations_summaries` | Violation counts only |
| `epa_sabs_geoms` + `epa_sabs_points` | `ServiceAreaGeometry` | `service_area_geometries` | Merged — polygon + centroid in one table |
| `epa_sabs_xwalk` | `Demographic` | `demographics` | ACS crosswalk data |
| `cejst` + `ejscreen` + `svi` + `cvi` | `EnvironmentalJustice` | `environmental_justices` | 4 tables consolidated into 1 |
| `pwsid_funded_highlevel_summary` | `FundingSummary` | `funding_summaries` | |
| `pwsid_npdes_usts_rmps_imp` | `WatershedHazard` | `watershed_hazards` | Pre-aggregated per PWS at import |
| `national_bwn_highlevel_summary` | `BoilWaterSummary` | `boil_water_summaries` | |
| `xwalk_pct_change_10yr` | `TrendDatum` | `trend_data` | |
| `pws_counties` | — | — | Denormalized as `counties` column on `public_water_systems` |
| `place_sabs_xtab` | `PlaceSystemCrosswalk` | `place_system_crosswalks` | |
| `wdt_mvt` | `TileCache` | `tile_cache` | |
| `file_import_tracker` | `DataImport` | `data_imports` | |
| `cartographic_state2022` | `CartographicState` | `cartographic_states` | Dropped year suffix |
| `cartographic_counties2022` | `CartographicCounty` | `cartographic_counties` | Dropped year suffix |
| `cartographic_places2022` | `CartographicPlace` | `cartographic_places` | Dropped year suffix |

---

## Column Mapping by Table

### `public_water_systems` (from `epa_sabs` + `sdwis_viols`)

**From `epa_sabs`:**

| Legacy Column | New Column | Type Change |
|--------------|------------|-------------|
| `pwsid` | `pwsid` | text → string (PK) |
| `pws_name` | `pws_name` | text → string |
| `primacy_agency` | `primacy_agency` | text → string |
| `pop_cat_5` | `pop_cat_5` | text → string |
| `population_served_count` | `population_served_count` | text → integer |
| `service_connections_count` | `service_connections_count` | text → integer |
| `service_area_type` | `service_area_type` | text → string |
| `symbology_field` | `symbology_field` | text → string |
| `detailed_facility_report` | `detailed_facility_report` | text → string |
| `ewg_report_link` | `ewg_report_link` | text → string |
| `epic_area_mi2` | `area_sq_miles` | text → decimal |

**From `sdwis_viols` (attribute columns that moved here):**

| Legacy Column | New Column | Type Change |
|--------------|------------|-------------|
| `gw_sw_code` | `gw_sw_code` | text → string |
| `primary_source_code` | `primary_source_code` | text → string |
| `first_reported_date` | `first_reported_date` | text → string (format varies) |
| `years_operating` | `years_operating` | text → integer |
| `owner_type` | `owner_type` | text → string |
| `primacy_type` | `primacy_type` | text → string |
| `is_grant_eligible_ind` | `is_grant_eligible` | text ("Y"/"N") → boolean |
| `is_wholesaler_ind` | `is_wholesaler` | text ("Y"/"N") → boolean |
| `is_school_or_daycare_ind` | `is_school_or_daycare` | text ("Y"/"N") → boolean |
| `source_water_protection_code` | `source_water_protection_code` | text → string |
| `phone_number` | `phone_number` | text → string |
| `open_health_viol` | `open_health_viol` | text → string |

**From `pws_counties`:**

| Legacy Column | New Column | Type Change |
|--------------|------------|-------------|
| `counties` | `counties` | text → text (denormalized onto PWS) |

**From `epa_sabs_points`:**

| Legacy Column | New Column | Type Change |
|--------------|------------|-------------|
| `stusps` | `stusps` | varchar(2) → string(2) |

---

### `violations_summaries` (from `sdwis_viols`, violation columns only)

| Legacy Column | New Column | Type Change |
|--------------|------------|-------------|
| `health_viols_5yr` | `health_violations_5yr` | text → integer |
| `groundwater_rule_healthbased_5yr` | `groundwater_rule_5yr` | text → integer |
| `surface_water_treatment_rules_healthbased_5yr` | `surface_water_treatment_5yr` | text → integer |
| `lead_and_copper_rule_healthbased_5yr` | `lead_and_copper_5yr` | text → integer |
| `radionuclides_and_revised_rad_rule_healthbased_5yr` | `radionuclides_5yr` | text → integer |
| `inorganic_chemicals_healthbased_5yr` | `inorganic_chemicals_5yr` | text → integer |
| `synthetic_organic_chemicals_healthbased_5yr` | `synthetic_organic_chemicals_5yr` | text → integer |
| `volatile_organic_chemicals_healthbased_5yr` | `volatile_organic_chemicals_5yr` | text → integer |
| `total_coliform_rules_healthbased_5yr` | `total_coliform_5yr` | text → integer |
| `stage_1_disinfectants_and_byproducts_rule_healthbased_5yr` | `stage_1_disinfectants_5yr` | text → integer |
| `stage_2_disinfectants_and_byproducts_rule_healthbased_5yr` | `stage_2_disinfectants_5yr` | text → integer |
| `paperwork_viols_5yr` | `paperwork_violations_5yr` | text → integer |
| `total_viols_5yr` | `total_violations_5yr` | text → integer |
| `health_viols_10yr` | `health_violations_10yr` | text → integer |
| `groundwater_rule_healthbased_10yr` | `groundwater_rule_10yr` | text → integer |
| `surface_water_treatment_rules_healthbased_10yr` | `surface_water_treatment_10yr` | text → integer |
| `lead_and_copper_rule_healthbased_10yr` | `lead_and_copper_10yr` | text → integer |
| `radionuclides_and_revised_rad_rule_healthbased_10yr` | `radionuclides_10yr` | text → integer |
| `inorganic_chemicals_healthbased_10yr` | `inorganic_chemicals_10yr` | text → integer |
| `synthetic_organic_chemicals_healthbased_10yr` | `synthetic_organic_chemicals_10yr` | text → integer |
| `volatile_organic_chemicals_healthbased_10yr` | `volatile_organic_chemicals_10yr` | text → integer |
| `total_coliform_rules_healthbased_10yr` | `total_coliform_10yr` | text → integer |
| `stage_1_disinfectants_and_byproducts_rule_healthbased_10yr` | `stage_1_disinfectants_10yr` | text → integer |
| `stage_2_disinfectants_and_byproducts_rule_healthbased_10yr` | `stage_2_disinfectants_10yr` | text → integer |
| `paperwork_viols_10yr` | `paperwork_violations_10yr` | text → integer |
| `total_viols_10yr` | `total_violations_10yr` | text → integer |
| `violations_all_years` | `violations_all_years` | text → integer |

---

### `demographics` (from `epa_sabs_xwalk`)

| Legacy Column | New Column | Type Change |
|--------------|------------|-------------|
| `total_pop` | `total_population` | text → integer |
| `epic_pop_density` | `population_density` | text → decimal |
| `mhi` | `median_household_income` | text → integer |
| `hh_inc_lowest_quintile` | `household_income_lowest_quintile` | text → integer |
| `hh_below_pov_per` | `poverty_rate` | text → decimal(5,2) |
| `pop_in_pov_per` | `population_in_poverty_rate` | text → decimal(5,2) |
| `laborforce_unemployed_per` | `unemployment_rate` | text → decimal(5,2) |
| `bachelors_per` | `bachelors_degree_rate` | text → decimal(5,2) |
| `no_health_insurance_per` | `no_health_insurance_rate` | text → decimal(5,2) |
| `ageunder_5_per` | `age_under_5_rate` | text → decimal(5,2) |
| `age_over_61_per` | `age_over_61_rate` | text → decimal(5,2) |
| `white_alone_per` | `white_rate` | text → decimal(5,2) |
| `black_alone_per` | `black_rate` | text → decimal(5,2) |
| `asian_alone_per` | `asian_rate` | text → decimal(5,2) |
| `aian_alone_per` | `aian_rate` | text → decimal(5,2) |
| `napi_alone_per` | `napi_rate` | text → decimal(5,2) |
| `hisp_alone_per` | `hispanic_rate` | text → decimal(5,2) |
| `other_alone_per` | `other_race_rate` | text → decimal(5,2) |
| `mixed_alone_per` | `mixed_race_rate` | text → decimal(5,2) |
| `poc_alone_per` | `poc_rate` | text → decimal(5,2) |
| `hh_rent_home_per` | `renter_rate` | text → decimal(5,2) |
| `hh_own_home_per` | `owner_rate` | text → decimal(5,2) |
| `water_rate_less_125_per` | `water_rate_under_125` | text → decimal(5,2) |
| `water_rate_between_125_249_per` | `water_rate_125_249` | text → decimal(5,2) |
| `water_rate_between_250_499_per` | `water_rate_250_499` | text → decimal(5,2) |
| `water_rate_between_500_749_per` | `water_rate_500_749` | text → decimal(5,2) |
| `water_rate_between_750_999_per` | `water_rate_750_999` | text → decimal(5,2) |
| `water_rate_over_1000_per` | `water_rate_over_1000` | text → decimal(5,2) |
| `most_common_rate_tidy` | `most_common_rate_tier` | text → string |

---

### `environmental_justices` (from `cejst` + `ejscreen` + `svi` + `cvi`)

| Legacy Table | Legacy Column | New Column | Type Change |
|-------------|--------------|------------|-------------|
| `cejst` | `a_int_identified_as_disadvantaged` | `cejst_disadvantaged_pct` | text → decimal (×100 at import) |
| `cejst` | `pw_int_hh_percent_pre_1960s_housing_lead_paint_indicator` | `cejst_lead_paint_indicator` | text → integer |
| `cejst` | `pw_int_pop_low_life_expectancy_percentile` | `cejst_low_life_expectancy_pctl` | text → decimal |
| `ejscreen` | `a_int_dwater` | `ejscreen_drinking_water` | text → decimal |
| `ejscreen` | `pw_ext_pop_disability` | `ejscreen_disability_rate` | text → decimal |
| `svi` | `pw_int_pop_rpl_themes` | `svi_overall_pctl` | text → decimal (×100 at import) |
| `cvi` | `pw_int_hh_redlining` | `cvi_redlining` | text → decimal |
| `cvi` | `pw_int_pop_life_expectancy` | `cvi_life_expectancy` | text → decimal |
| `cvi` | `pw_int_pop_cancer` | `cvi_cancer_risk` | text → decimal |
| `cvi` | `a_int_overall_cvi_score` | `cvi_overall_score` | text → decimal (×100 at import) |

**Why consolidate?** These four tables each have 1–4 columns plus `pwsid`. Four separate models/tables with 1–4 data columns each is unnecessary overhead. They all describe the same concept (environmental/social justice indicators) and are always queried together.

---

### `watershed_hazards` (from `pwsid_npdes_usts_rmps_imp`)

| Legacy Column | New Column | Type Change |
|--------------|------------|-------------|
| `num_facilities` | `num_facilities` | text → integer |
| `npdes_permits` | `npdes_permits` | text → integer |
| `total_permit_eff_viols` | `permit_effluent_violations` | text → integer |
| `total_open_usts` | `open_underground_storage_tanks` | text → integer |
| `total_facilities_w_rmps` | `risk_management_plan_facilities` | text → integer |
| `streams_303d_list` | `impaired_streams_303d` | text → integer |

**Why pre-aggregate?** The legacy table has one row per HUC12 watershed per PWS. Both `wdt_mvt.php` and `download_geojson.php` aggregate with `GROUP BY pwsid, SUM(...)` at query time. Pre-aggregating at import eliminates this repeated work. The `huc12` column is dropped — it was only used as the grouping dimension.

---

### `trend_data` (from `xwalk_pct_change_10yr`)

| Legacy Column | New Column | Type Change |
|--------------|------------|-------------|
| `total_pop_pct_change_2011_2021` | `population_pct_change` | text → decimal |
| `laborforce_unemployed_pct_change_2011_2021` | `unemployment_pct_change` | text → decimal |
| `mhi_pct_change_2011_2021` | `mhi_pct_change` | text → decimal |
| `hh_inc_lowest_quintile_pct_change_2011_2021` | `lowest_quintile_pct_change` | text → decimal |
| `hh_total_pct_change_2011_2021` | `households_pct_change` | text → decimal |
| `hh_below_pov_pct_change_2011_2021` | `poverty_pct_change` | text → decimal |
| `poc_alone_per_pct_change_2011_2021` | `poc_pct_change` | text → decimal |
| `pop_in_pov_per_pct_change_2011_2021` | `population_in_poverty_pct_change` | text → decimal |
| `income_change_flag` | `income_change_flag` | text → string |
| `population_change_flag` | `population_change_flag` | text → string |
| `total_pop_pct_change_2011_2021_cap` | `population_pct_change_capped` | text → decimal |
| `mhi_pct_change_2011_2021_cap` | `mhi_pct_change_capped` | text → decimal |

---

## Value Transformations

| Pattern | Legacy | New | Examples |
|---------|--------|-----|----------|
| Boolean indicators | text `"Y"` / `"N"` | `boolean` | `is_wholesaler_ind`, `is_school_or_daycare_ind`, `is_grant_eligible_ind` |
| Integer counts | text `"42"` | `integer` | Population, violations, funding counts |
| Decimal values | text `"0.85"` | `decimal` | Percentages, scores, areas |
| 0-to-1 scores | text `"0.65"` | `decimal` (×100 at import) | CEJST disadvantaged, SVI percentile, CVI score |
| NULL handling | text `"NA"` | SQL `NULL` | All columns — legacy ETL already maps `"NA"` → `NULL` |

---

## Columns Dropped

| Legacy Table | Column | Reason |
|-------------|--------|--------|
| `pwsid_npdes_usts_rmps_imp` | `huc12` | Only used as aggregation dimension; pre-aggregated in new schema |
| `cartographic_*` | `statens`, `countyns`, `placens`, `lsad`, `aland`, `awater` | Census metadata not used by the app |
| `cartographic_*` | `affgeoid` | Redundant with `geoid` |
| `national_bwn_summary` | (entire table) | Superseded by `national_bwn_highlevel_summary` |
| `pwsid_summarized_funding_data` | (entire table) | Superseded by `pwsid_funded_highlevel_summary` |

---

## Phased Implementation Plan

### Phase 1: Foundation
- `rails new` with PostgreSQL, PostGIS, Hotwire, Tailwind
- Docker Compose for local dev (Postgres + PostGIS container)
- All migrations (create every table from SCHEMA.md)
- Models with associations and basic validations
- Seed data: export 1–2 states from S3, transform to new schema, load via Rake task

### Phase 2: Filter API + Tiles
- `PublicWaterSystemsController#index` with filter params → SQL scopes
- `Filterable` concern with all filter scopes
- `TilesController#show` with PostGIS `ST_AsMVT` generation + cache
- JSON responses for filter API

### Phase 3: Frontend
- Mapbox GL JS integration via Stimulus controller
- Filter panel with Turbo Frame updates
- Data table with server-side pagination
- System detail panel
- Printable report view

### Phase 4: ETL Pipeline
- Rake task / SolidQueue job replacing `scheduled_data_import.py`
- S3 manifest polling
- CSV/GeoJSON import with type casting
- Post-import steps (geometry repair, centroid generation, spatial joins)
- Tile cache invalidation

### Phase 5: Export + Downloads
- CSV export with filter params
- GeoJSON export (streaming for large result sets)
- Bulk download page linking to S3 zip files

### Phase 6: Polish + Deploy
- Performance testing with full national dataset
- Provision new infrastructure in EPIC's AWS account (EC2 + RDS)
- Deploy Rails app
- Mapbox token migration (URL-restricted token for EPIC's domain)
- Google Analytics migration
- DNS cutover to new infrastructure

---

## Data Seeding Strategy

For local development, seed the database with a representative subset:

1. Download 1–2 state zip files from the S3 bulk downloads (e.g., Vermont + Rhode Island — small, fast to load)
2. Write a Rake task (`db:seed:states[VT,RI]`) that:
   - Extracts CSVs from the zip files
   - Imports rows matching those states' `pwsid` prefixes into each table with proper type casting
   - Runs post-import steps (centroids, county join, place crosswalk)
3. Commit the seed Rake task, not the seed data itself (data is too large for git)

---

## Cutover Strategy

The new app should be deployed to entirely new infrastructure under the recipient organization's AWS account — this is not an in-place migration.

1. **Provision new infra:** Fresh EC2/ECS host and RDS PostgreSQL+PostGIS instance in your AWS account
2. **Deploy Rails app** to the new EC2 instance
3. **Set ETL source configuration** (`ETL_MANIFEST_URL`, bucket/path ownership, IAM permissions)
4. **Run ETL** to populate the new database from scratch — no data migration from the old DB
5. **Load cartographic boundaries** into the new DB (export from old DB or source from Census)
6. **Verify:** Filter results match legacy app, tile rendering looks correct, exports produce equivalent output
7. **Transfer DNS** to point your domain at the new infrastructure
8. **Transfer remaining services:** Mapbox account (URL-restricted token), analytics property, and any monitoring/alerts
9. **Decommission old infra** once stakeholders confirm the new app is stable
