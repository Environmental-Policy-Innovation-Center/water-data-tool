# API Reference

> Endpoint specifications for the Drinking Water Explorer. All endpoints are public — no authentication required.

The app uses a **Hotwire-first** architecture. Most UI data is server-rendered HTML (Turbo Frames), not JSON. See `docs/FRONTEND_DECISION.md` for the decision record.

---

## Overview

| Endpoint | Method | Returns | Purpose |
|----------|--------|---------|---------|
| `/` | GET | HTML | App shell (map, filters, table) |
| `/map` | GET | JSON | Filtered `pwsid` list for map polygon highlighting |
| `/table` | GET | HTML | Data table Turbo Frame partial |
| `/public_water_systems/stats` | GET | HTML | Stats bar Turbo Frame partial |
| `/public_water_systems/export` | POST | CSV / GeoJSON (streaming) | Filtered or row-selected data download |
| `/public_water_systems/histogram` | GET | JSON | Histogram bins for range sliders |
| `/public_water_systems/:pwsid/report` | GET | HTML | Printable system report |
| `/places/search` | GET | JSON | Place autocomplete for filter UI |
| `/tiles/:z/:x/:y` | GET | MVT (protobuf) | Map vector tiles |

There is **no** general-purpose JSON list or detail API (`GET /public_water_systems`, `GET /public_water_systems/:pwsid`) — those endpoints were removed in June 2026.

---

## Shared filter parameters

Most data endpoints accept the same filter query params defined in `config/filters.yml` and applied by `PublicWaterSystem.apply_filters`. Full param reference: `docs/FILTERING.md`.

Endpoints that accept filters: `/map`, `/table`, `/public_water_systems/stats`, `POST /public_water_systems/export`.

---

## `GET /map`

Returns the `pwsid` values matching the current filters. Used by `map_controller.js` to apply Mapbox polygon filters.

### Response

```json
{
  "pwsids": ["VT0020001", "VT0020002"]
}
```

---

## `GET /table`

Renders `home/_table.html.erb` inside `<turbo-frame id="data-table">`. Consumed by Turbo Frame navigation from `filter_controller.js` — not a general JSON API.

### Pagination & sorting

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `page` | integer | 1 | Page number (Pagy) |
| `search` | string | — | ILIKE search across `pws_name`, `pwsid`, `stusps`, `counties` |
| `sort` | string | `pws_name` | Column to sort by (allowlisted in `HomeController`) |
| `direction` | string | `asc` | `asc` or `desc` |

Plus all shared filter params.

---

## `GET /public_water_systems/stats`

Aggregate summary stats for the stats bar. Returns HTML (not JSON) rendered into `<turbo-frame id="stats-bar">`.

Accepts shared filter params. Response includes systems count (filtered vs total), total customers served, average area MHI, and open-violations count.

---

## `POST /public_water_systems/export`

Streaming data download. Accepts shared filter params plus row-selection params. See `docs/EXPORTS.md` for the full design.

### Request body parameters

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `file_format` | string | `csv` | `csv` or `geojson` |
| `cols` | string | — | Comma-separated column keys; restricts CSV columns to the user's visible set |
| `sort` | string | `pws_name` | Column to sort by |
| `direction` | string | `asc` | `asc` or `desc` |
| `search` | string | — | ILIKE search (same as `/table`) |
| `pwsids[]` | string[] | — | Explicit row selection (None mode). When present, filter params are ignored. |
| `exclude_pwsids[]` | string[] | — | Exclusion list (All mode with some unchecked rows) |

Plus all shared filter params.

### CSV response

- `Content-Type: text/csv`
- `Content-Disposition: attachment; filename="drinking_water_explorer_export.csv"`
- Streaming — no `Content-Length`; columns match the user's visible column set

### GeoJSON response

- `Content-Type: application/json; charset=utf-8`
- `Content-Disposition: attachment; filename="export.geojson"`
- Streaming `FeatureCollection` with `MultiPolygon` geometries; all columns regardless of `cols=`

---

## `GET /public_water_systems/histogram`

Histogram distribution for a filter slider field. Used by `slider_controller.js`.

### Query parameters

| Param | Type | Description |
|-------|------|-------------|
| `field` | string | Allowlisted field name (`PublicWaterSystems::HistogramsController::ALLOWED_FIELDS`) |

### Response

```json
{
  "bins": [{"min": 0, "max": 10, "count": 42}],
  "domain_min": 0,
  "domain_max": 100
}
```

Returns `400` with `{ "error": "Unknown field" }` for unrecognized fields.

---

## `GET /public_water_systems/:pwsid/report`

Printable HTML report for a single system. `pwsid` may contain semicolons (compound IDs); URL-encode as needed.

- **Turbo Frame request** — renders without layout (overlay on map page)
- **Direct visit** — full-page layout with print and back-to-map controls

Returns `404` plain text if not found.

---

## `GET /places/search`

Place autocomplete for the Boundaries filter.

### Query parameters

| Param | Type | Description |
|-------|------|-------------|
| `q` | string | Search prefix |

### Response

```json
[
  {"geoid": "5010675", "name": "Burlington", "stusps": "VT"}
]
```

Max 10 results. Cached 1 hour (`Cache-Control: public, max-age=3600`).

---

## `GET /tiles/:z/:x/:y`

Mapbox Vector Tile (MVT) binary protobuf.

| Param | Type | Description |
|-------|------|-------------|
| `z` | integer | Zoom level (0–22) |
| `x` | integer | Tile column |
| `y` | integer | Tile row |

Layers: `pws`, `places`, `counties`, `states`.

---

## Manual testing

```bash
docker compose up -d
bin/dev
mkdir -p tmp/test_exports
```

### Map filter

```bash
curl "http://localhost:3000/map?state=VT" | jq
```

### Table (HTML)

```bash
curl "http://localhost:3000/table?state=VT&page=1" | head -20
```

### Export

```bash
# CSV — all VT systems (filter-based, all rows selected)
curl -X POST "http://localhost:3000/public_water_systems/export" \
  -d "state=VT" \
  -H "X-CSRF-Token: $(curl -s http://localhost:3000/ | grep csrf-token | sed 's/.*content="\([^"]*\)".*/\1/')" \
  -o tmp/test_exports/vt_export.csv

# GeoJSON — explicit row selection
curl -X POST "http://localhost:3000/public_water_systems/export" \
  -d "file_format=geojson&pwsids[]=VT0020001&pwsids[]=VT0020002" \
  -o tmp/test_exports/selected_export.geojson
```

### Histogram

```bash
curl "http://localhost:3000/public_water_systems/histogram?field=paperwork_violations_5yr" | jq
```

### Report

```bash
curl "http://localhost:3000/public_water_systems/VT0020001/report" | head -20
```
