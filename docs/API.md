# API Reference

> Endpoint specifications for the Drinking Water Explorer. All endpoints are public — no authentication required.

---

## Overview

| Endpoint | Method | Returns | Purpose |
|----------|--------|---------|---------|
| `/public_water_systems` | GET | JSON | Filtered list of water systems |
| `/public_water_systems/:pwsid` | GET | JSON / HTML | Single system detail |
| `/public_water_systems/:pwsid/report` | GET | HTML | Printable report |
| `/public_water_systems/export` | GET | CSV / GeoJSON | Filtered data download |
| `/tiles/:z/:x/:y` | GET | MVT (protobuf) | Map vector tiles |
| `/datasets` | GET | HTML | Dataset descriptions page |
| `/downloads` | GET | HTML | Bulk download links page |

---

## `GET /public_water_systems`

Returns a paginated, filtered list of public water systems. This is the primary data endpoint — the filter UI, map, and table all consume it.

### Query Parameters

#### Pagination & Sorting

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `page` | integer | 1 | Page number |
| `per_page` | integer | 50 | Results per page (max 500) |
| `sort_by` | string | `pwsid` | Column to sort by |
| `sort_dir` | string | `asc` | `asc` or `desc` |

#### Source Filters

| Param | Type | Description |
|-------|------|-------------|
| `gw_sw_code` | string | `"Groundwater"` or `"Surface Water"` |
| `has_source_protection` | boolean | `true` to show only systems with source water protection |

#### Attribute Filters

| Param | Type | Description |
|-------|------|-------------|
| `owner_type[]` | array of strings | Filter by ownership. Values: `Federal`, `State`, `Local`, `Native American`, `Private`, `Public/Private` |
| `primacy_type[]` | array of strings | Filter by regulatory authority. Values: `State`, `Tribal`, `Territory` |
| `is_wholesaler` | boolean | `true` to show only wholesalers |
| `is_school_or_daycare` | boolean | `true` to show only school/daycare systems |

#### Boundary Filters

| Param | Type | Description |
|-------|------|-------------|
| `service_area_type` | string | `"System Sourced"` or `"Modeled"` |
| `area_min` | decimal | Minimum service area in square miles |
| `area_max` | decimal | Maximum service area in square miles |

#### Compliance Filters

| Param | Type | Description |
|-------|------|-------------|
| `has_open_violations` | boolean | `true` to show only systems with open health violations |
| **5-year health violation sub-rules** | | |
| `groundwater_rule_5yr_min` / `_max` | integer | Ground water rule violations (5yr) |
| `surface_water_treatment_5yr_min` / `_max` | integer | Surface water treatment violations (5yr) |
| `lead_and_copper_5yr_min` / `_max` | integer | Lead & copper violations (5yr) |
| `radionuclides_5yr_min` / `_max` | integer | Radionuclides violations (5yr) |
| `inorganic_chemicals_5yr_min` / `_max` | integer | Inorganic chemical violations (5yr) |
| `synthetic_organic_chemicals_5yr_min` / `_max` | integer | Synthetic organic chemical violations (5yr) |
| `volatile_organic_chemicals_5yr_min` / `_max` | integer | Volatile organic chemical violations (5yr) |
| `total_coliform_5yr_min` / `_max` | integer | Coliform violations (5yr) |
| `stage_1_disinfectants_5yr_min` / `_max` | integer | Stage 1 disinfectant violations (5yr) |
| `stage_2_disinfectants_5yr_min` / `_max` | integer | Stage 2 disinfectant violations (5yr) |
| `paperwork_violations_5yr_min` / `_max` | integer | Non-health violations (5yr) |
| **10-year health violation sub-rules** | | Same pattern as 5yr, with `_10yr` suffix |
| `boil_water_notices_min` / `_max` | integer | Total boil water notices |

#### Population Filters

| Param | Type | Description |
|-------|------|-------------|
| `pop_cat_5[]` | array of strings | EPA size category. Values: `Very Small`, `Small`, `Medium`, `Large`, `Very Large` |
| `density_min` / `_max` | decimal | People per square mile |
| `total_population_min` / `_max` | integer | Total population served |

#### Demographic Filters (via `demographics` join)

| Param | Type | Description |
|-------|------|-------------|
| `poverty_rate_min` / `_max` | decimal | % households below poverty line |
| `unemployment_rate_min` / `_max` | decimal | % labor force unemployed |
| `median_household_income_min` / `_max` | integer | Annual MHI in dollars |
| `bachelors_degree_rate_min` / `_max` | decimal | % with bachelor's degree |
| `age_under_5_rate_min` / `_max` | decimal | % population under 5 |
| `age_over_61_rate_min` / `_max` | decimal | % population over 61 |
| `poc_rate_min` / `_max` | decimal | % people of color |
| `white_rate_min` / `_max` | decimal | % White |
| `black_rate_min` / `_max` | decimal | % Black |
| `aian_rate_min` / `_max` | decimal | % American Indian / Alaska Native |
| `napi_rate_min` / `_max` | decimal | % Native Hawaiian / Pacific Islander |
| `asian_rate_min` / `_max` | decimal | % Asian |
| `hispanic_rate_min` / `_max` | decimal | % Hispanic / Latino |
| `other_race_rate_min` / `_max` | decimal | % Other race |
| `mixed_race_rate_min` / `_max` | decimal | % Mixed race |

#### Vulnerability Filters (via `environmental_justices` join)

| Param | Type | Description |
|-------|------|-------------|
| `cejst_disadvantaged_pct_min` / `_max` | decimal | % area identified as disadvantaged (0–100) |
| `svi_overall_pctl_min` / `_max` | decimal | Social Vulnerability Index percentile (0–100) |
| `cvi_overall_score_min` / `_max` | decimal | Climate Vulnerability Index score (0–100) |

#### Financial Filters

| Param | Type | Description |
|-------|------|-------------|
| `most_common_rate_tier` | string | Water/sewer bill tier (e.g., `"Less than $125"`) |
| `times_funded_min` / `_max` | integer | SRF financing count (via `funding_summaries` join) |
| `total_srf_assistance_min` / `_max` | decimal | Total SRF dollars received |
| `total_principal_forgiveness_min` / `_max` | decimal | Total principal forgiveness |

#### Environmental Filters (via `watershed_hazards` join)

| Param | Type | Description |
|-------|------|-------------|
| `num_facilities_min` / `_max` | integer | Source water connections |
| `permit_effluent_violations_min` / `_max` | integer | Pollution permits with breaches |
| `open_underground_storage_tanks_min` / `_max` | integer | Open USTs |
| `risk_management_plan_facilities_min` / `_max` | integer | RMP facilities |
| `impaired_streams_303d_min` / `_max` | integer | Impaired/threatened streams |

#### Trend Filters (via `trend_data` join)

| Param | Type | Description |
|-------|------|-------------|
| `population_pct_change_min` / `_max` | decimal | 10yr population change (%) |
| `mhi_pct_change_min` / `_max` | decimal | 10yr income change (%) |

#### Geographic Filters

| Param | Type | Description |
|-------|------|-------------|
| `state` | string | State USPS abbreviation (e.g., `"OH"`) |
| `county_geoid` | string | 5-digit county FIPS code |
| `place_geoid` | string | 7-digit census place GEOID |
| `bounds` | string | Bounding box `"west,south,east,north"` (for map viewport filtering) |

### Response

```json
{
  "total_count": 1234,
  "page": 1,
  "per_page": 50,
  "results": [
    {
      "pwsid": "OH0100013",
      "pws_name": "VILLAGE OF ADDYSTON",
      "stusps": "OH",
      "pop_cat_5": "Very Small",
      "population_served_count": 891,
      "service_connections_count": 420,
      "gw_sw_code": "Groundwater",
      "owner_type": "Local",
      "primacy_type": "State",
      "service_area_type": "Modeled",
      "area_sq_miles": 1.2,
      "open_health_viol": "No",
      "is_wholesaler": false,
      "is_school_or_daycare": false
    }
  ],
  "summary": {
    "systems_count": 1234,
    "total_population_served": 2345678,
    "systems_with_open_violations": 89
  }
}
```

---

## `GET /public_water_systems/:pwsid`

Returns a single system with all associated data.

### Response

```json
{
  "pwsid": "OH0100013",
  "pws_name": "VILLAGE OF ADDYSTON",
  "stusps": "OH",
  "primacy_agency": "Ohio EPA",
  "population_served_count": 891,
  "service_connections_count": 420,
  "gw_sw_code": "Groundwater",
  "owner_type": "Local",
  "primacy_type": "State",
  "area_sq_miles": 1.2,
  "counties": "Hamilton County, OH",
  "detailed_facility_report": "https://...",
  "ewg_report_link": "https://...",

  "demographic": {
    "total_population": 891,
    "median_household_income": 45200,
    "poverty_rate": 12.3,
    "unemployment_rate": 5.1,
    "poc_rate": 18.7,
    "most_common_rate_tier": "Less than $125"
  },

  "violations_summary": {
    "health_violations_5yr": 2,
    "lead_and_copper_5yr": 1,
    "total_coliform_5yr": 1,
    "paperwork_violations_5yr": 0,
    "health_violations_10yr": 3,
    "violations_all_years": 7
  },

  "environmental_justice": {
    "cejst_disadvantaged_pct": 65,
    "svi_overall_pctl": 78,
    "cvi_overall_score": 42,
    "ejscreen_drinking_water": 88.5
  },

  "funding_summary": {
    "times_funded": 2,
    "total_srf_assistance": 1250000.00,
    "total_principal_forgiveness": 500000.00
  },

  "watershed_hazard": {
    "num_facilities": 3,
    "npdes_permits": 12,
    "permit_effluent_violations": 2,
    "open_underground_storage_tanks": 5,
    "impaired_streams_303d": 1
  },

  "boil_water_summary": {
    "total_notices": 3,
    "first_advisory_date": "2022-01-15",
    "last_advisory_date": "2024-06-30",
    "tooltip_text": "Continuous data collection started on..."
  },

  "trend_datum": {
    "population_pct_change": -2.5,
    "mhi_pct_change": 8.1,
    "poverty_pct_change": -1.2
  }
}
```

Returns `404` if the `pwsid` is not found.

---

## `GET /public_water_systems/:pwsid/report`

Returns an HTML page optimized for printing. Not a JSON endpoint.

---

## `GET /public_water_systems/export`

Accepts the same filter parameters as the index endpoint. Returns a file download.

### Additional Parameters

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `format` | string | `csv` | `csv` or `geojson` |

### CSV Response

- `Content-Type: text/csv`
- `Content-Disposition: attachment; filename="drinking_water_explorer_export.csv"`
- Includes all columns from the system and its associations (flat structure)
- No pagination — returns all matching systems

### GeoJSON Response

- `Content-Type: application/json`
- `Content-Encoding: gzip`
- Standard GeoJSON `FeatureCollection` with `MultiPolygon` geometries
- Properties include all columns from the system and its associations (flat structure, matching the legacy `download_geojson.php` output)

---

## `GET /tiles/:z/:x/:y`

Returns a Mapbox Vector Tile (MVT) binary protobuf containing map geometry data.

### Parameters

| Param | Type | Description |
|-------|------|-------------|
| `z` | integer | Zoom level (0–22) |
| `x` | integer | Tile column |
| `y` | integer | Tile row |

### Response

- `Content-Type: application/x-protobuf`
- `Cache-Control: max-age=600` (10 minutes)
- Binary MVT data containing multiple layers

### Layers

| Layer | Contents |
|-------|----------|
| `pws` | Service area polygons (`pwsid`, `stusps`) |
| `pws_points` | System centroids with core display attributes |
| `places` | Census place boundaries with associated PWS IDs |
| `counties` | County boundaries with associated PWS IDs |
| `states` | State boundaries |

---

## Error Responses

All errors return a JSON body:

```json
{
  "error": "Description of the error",
  "status": 404
}
```

| Status | Meaning |
|--------|---------|
| 400 | Invalid filter parameters |
| 404 | System not found (for `:pwsid` endpoints) |
| 500 | Internal server error |
