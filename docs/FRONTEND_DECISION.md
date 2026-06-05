# Frontend Architecture Decision

**Status:** Decided — Hotwire

---

## Decision

Build the Drinking Water Explorer as a **Rails 8 Hotwire app**: server-rendered HTML, Stimulus for client behavior, Turbo Frames for partial page updates.

---

## Context

The legacy app was jQuery, DataTables, and PHP. The rebuild uses Hotwire throughout:

- `HomeController` — app shell, data table, and map filter JSON
- Turbo Frames — stats bar and table updates without full page reloads
- Stimulus — map, filters, exports, histogram sliders, and report overlay
- Nested `/public_water_systems/*` endpoints — export, stats, histogram, and printable report

---

## Why Hotwire

- The app was already on working Hotwire patterns before this was formalized.
- The team is Rails-primary.
- The UI scope — map, filters, wide data table, printable report — fits server-rendered partials.
- Mapbox, ETL, PostGIS tiles, and the `Filterable` concern are backend concerns independent of how HTML is delivered.

---

## What We Did

### Table modernization (completed)

- Replaced DataTables + jQuery with server-rendered `home/_table.html.erb` inside `<turbo-frame id="data-table">`.
- `HomeController#table` renders an HTML partial (Pagy pagination, server-side sort/search).
- Removed DataTables CDN, jQuery, and `table_controller.js`.

### Dead code removal (June 2026)

Removed unused controller, serializer, and view code from early M3 scaffolding that was never connected to the UI:

| Removed | Reason |
|---------|--------|
| `PublicWaterSystemsController` (`index`, `show`) | No frontend callers |
| `PublicWaterSystemSerializer` | Only used by removed `index` |
| `PublicWaterSystemDetailSerializer` | Only used by removed `show` |
| `PublicWaterSystemTableSerializer` | Written for DataTables JSON; table now renders ERB directly |
| `public_water_systems/show.html.erb` | Superseded by report flow |
| Associated request/serializer specs | Tests for removed code |

### Live endpoints

| Endpoint | Controller | Format | Used by |
|----------|------------|--------|---------|
| `GET /` | `HomeController#index` | HTML | App shell |
| `GET /map` | `HomeController#map` | JSON | `map_controller.js` |
| `GET /table` | `HomeController#table` | HTML (Turbo Frame) | `filter_controller.js` |
| `GET /public_water_systems/stats` | `PublicWaterSystems::StatsController` | HTML (Turbo Frame) | `filter_controller.js` |
| `GET /public_water_systems/export` | `PublicWaterSystems::ExportsController` | CSV / GeoJSON | `export_controller.js` |
| `GET /public_water_systems/histogram` | `PublicWaterSystems::HistogramsController` | JSON | `slider_controller.js` |
| `GET /public_water_systems/:pwsid/report` | `PublicWaterSystems::ReportsController` | HTML | `map_controller.js` |

---

## Current request flow

```
Browser loads /
  └── HomeController#index (app shell)
        filter_controller.js
          ├── GET /map                          → map_controller (polygon filter)
          ├── GET /table                        → <turbo-frame id="data-table">
          └── GET /public_water_systems/stats   → <turbo-frame id="stats-bar">
        map_controller.js     → Mapbox + popups → /public_water_systems/:pwsid/report
        export_controller.js  → /public_water_systems/export
        slider_controller.js  → /public_water_systems/histogram
```

---

## What stays the same

- **Mapbox GL JS** — client-side (Stimulus controller)
- **`Filterable` concern** — server-side filter logic shared across all endpoints
- **ETL pipeline** — unaffected
- **PostGIS vector tiles** — `TilesController` unchanged
- **Data model** — no schema changes from this decision

See `docs/API.md` for the current endpoint reference.
