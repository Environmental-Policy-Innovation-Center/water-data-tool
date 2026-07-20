# Architecture

> How the Rails 8 app is structured. Where to find things, where to put new code.

---

## Stack

| Layer | Choice |
|-------|--------|
| Framework | Rails 8 |
| Frontend | Hotwire (Turbo + Stimulus) + Tailwind CSS |
| Database | PostgreSQL 15+ with PostGIS |
| Background jobs | SolidQueue |
| Map rendering | Mapbox GL JS v3 |
| Testing | RSpec + FactoryBot + Shoulda Matchers |
| Local dev | Docker Compose |

---

## Directory Layout

This is a mostly-standard Rails app, with a few extra `app/` directories that hold the **config-driven data layer**. The guide below is by directory and purpose — "what lives here and when would I touch it" — so it stays useful as individual files come and go. When in doubt, open the directory.

### The config-driven data layer (start here)

A **data field** (say, `population_served`) is declared once in config and the app derives everything from that declaration — its table column, its filter, its ETL mapping, its export column. Four YAML files own this, each read by one Ruby directory:

| Config file | Read by | Owns |
|-------------|---------|------|
| `config/fields.yml` — the **manifest** | `app/fields/` (`FieldRegistry`, `FieldDefinition`) | What each field *is*: how it's ingested (`source`), displayed (`display`), filtered (`filter`), charted (`histogram`). The single source of truth. |
| `config/filter_layout.yml` | `app/filters/` (`FilterLayout`) | Where a filter *appears* — its menu/category, nesting, order, and the AND/OR grouping. `app/filters/` also holds `FilterParams` (permits + decodes filter params). |
| `config/table_layout.yml` | `app/columns/` (`TableLayout`, `ColumnRegistry`) | Which columns show, their order, and picker grouping. `ColumnRegistry` builds each column from manifest × layout; `TableColumn`/`CategoryDef` are the value objects. |
| `config/tooltips.yml` | (loaded where copy is rendered) | User-facing tooltip/help text, kept out of the structural config. |

### The rest of `app/`

| Directory | What lives here |
|-----------|-----------------|
| `controllers/` | Thin HTTP entry points. `home_controller` (root page, `GET /map` JSON, `GET /table`), `public_water_systems/*` (stats, export, histogram, report), `tiles_controller` (MVT tiles). |
| `models/` | One ActiveRecord model per table. `public_water_system` is the hub (string `pwsid` PK); the rest (`demographic`, `violations_summary`, `funding_summary`, …) are `has_one` satellites joined on `pwsid`. `models/concerns/filterable.rb` is the filter combiner (see [Filter Architecture](#filter-architecture)). |
| `exporters/` | Streaming CSV / GeoJSON generation (`to_csv_stream`, `to_geojson_stream`) — builds rows straight from SQL, no ActiveRecord objects, for large downloads. |
| `components/` | [ViewComponents](https://viewcomponent.org/) — server-rendered UI widgets with their own class + template, grouped by area (`filters/`, `ui/`, `manage_columns/`, `report/`). `previews/` holds Lookbook previews for developing them in isolation. |
| `services/` | Plain-Ruby objects for logic that isn't a model or controller: `etl/` (the ingest pipeline — see [ETL.md](ETL.md)), `tile_generator` / `tile_impact` (PostGIS MVT tiles), `url_state_codec` (filter-state URL encoding), `cartographic_boundaries`, `boil_water_state_config` (BWN-eligible states + per-state tooltip copy, sourced from `config/tooltips.yml`). |
| `jobs/` | SolidQueue background jobs: `etl_import_job`, `tile_cache_refresh_job`, `tile_cache_warm_job`. |
| `javascript/` | Stimulus controllers in `controllers/`, plus shared singletons `filter_state.js` and `selection_state.js`. See [Stimulus Controllers](#stimulus-controllers). |
| `views/` | ERB. `home/index.html.erb` is the app shell; the `home/_filter_*.html.erb` partials are the **generated** filter menus (driven by the manifest × layout, not hand-authored). `public_water_systems/` holds the report, stats-bar frame, and shared section partials. |

### Outside `app/`

| Path | What lives here |
|------|-----------------|
| `config/` | `routes.rb`, the four data-config files above, `datasets.yml`, `recurring.yml` (SolidQueue schedule), env initializers. |
| `db/` | `migrate/` schema migrations and `seeds.rb`. |
| `lib/tasks/` | Rake tasks — `etl.rake` (`bin/rails etl:import`), `seed_states.rake`, `seed_geometries.rake`. |
| `spec/` | RSpec, mirroring `app/`: `models/`, `requests/`, `jobs/`, `fields/`, `filters/`, `columns/`, `components/`, `services/`, plus `factories/` and `support/`. |

---

## Models

### Primary Key Pattern

`PublicWaterSystem` uses `pwsid` (a string like `"OH0100013"`) as its primary key — not an auto-incrementing integer.

```ruby
class PublicWaterSystem < ApplicationRecord
  self.primary_key = "pwsid"

  has_one :service_area_geometry, foreign_key: "pwsid"
  has_one :demographic, foreign_key: "pwsid"
  has_one :violations_summary, foreign_key: "pwsid"
  has_one :environmental_justice, foreign_key: "pwsid"
  has_one :funding_summary, foreign_key: "pwsid"
  has_one :watershed_hazard, foreign_key: "pwsid"
  has_one :boil_water_summary, foreign_key: "pwsid"
  has_one :trend_datum, foreign_key: "pwsid"
end
```

Each associated model:

```ruby
class Demographic < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid"
end
```

---

## Controllers

### `HomeController`

Primary data surface for the Hotwire UI. See [docs/decisions/FRONTEND_DECISION.md](decisions/FRONTEND_DECISION.md) for the frontend architecture decision.

- **`index`** — renders `home/index.html.erb`, the main app page (map, filter bar, table, all UI).
  Also queries `DataImport.maximum(:imported_at)` for the "last updated" display.
- **`map`** — `GET /map`. Returns `{ pwsids: [...] }` for the filtered set. Used by `map_controller.js`
  to apply Mapbox polygon filters.
- **`table`** — `GET /table`. Renders `home/_table.html.erb` inside `<turbo-frame id="data-table">`.
  Applies `Filterable#apply_filters`, optional search, Pagy pagination, and server-side sort
  (`sort`, `direction` params).

### `PublicWaterSystems::*` (nested controllers)

Utility endpoints namespaced under `/public_water_systems/`.

- **`ExportsController#create`** — `POST /public_water_systems/export`. Streaming CSV or GeoJSON download. Accepts filter params, `pwsids[]`, `exclude_pwsids[]`, `cols`, `sort`, `direction`, `search`. See `docs/EXPORTS.md`.
- **`StatsController#show`** — `GET /public_water_systems/stats`. Turbo Frame HTML partial for the stats bar.
- **`HistogramsController#show`** — `GET /public_water_systems/histogram?field=`. JSON histogram bins for sliders.
- **`ReportsController#show`** — `GET /public_water_systems/:pwsid/report`. Printable report (overlay or full page).

### `TilesController`

- **`show`** — receives `z/x/y` params, checks `TileCache`, generates MVT via PostGIS `ST_AsMVT`
  on cache miss, returns binary protobuf with `Content-Type: application/x-protobuf`.

---

## Filter Architecture

Filters flow from the URL to SQL: `FilterParams` (`app/filters/`) permits and decodes the params, then `PublicWaterSystem.apply_filters` — the `Filterable` concern (`app/models/concerns/filterable.rb`) — turns them into a scope.

The concern is **config-driven, not hardcoded** — there is no per-field `if params[...]` list. It reads each filter's kind, param, and table from the manifest (`FieldRegistry` / `config/fields.yml`) and groups filters by their menu category (`FilterLayout.category_of`). Joins are derived from each field's `model:`, so no join SQL is hand-written. The public entry point is `apply_filters(params)`; the internals split into `apply_category_filters`, `apply_direct_filters`, `apply_rate_tier_filter`, and `apply_geographic_filters`.

**Combination logic — the grouping *is* the boolean:**
- **Within a category:** OR (e.g. two `owner_type` values match either).
- **Across categories:** AND (a system must satisfy every active category).

So which category you place a filter in (in `config/filter_layout.yml`) decides how it combines. See **[FILTERING.md](FILTERING.md)** for the full model.

---

## Stimulus Controllers

Client behavior lives in `app/javascript/controllers/`. Each file is a **Stimulus controller** — a small JS class attached to markup via a `data-controller="name"` attribute, so the server renders the HTML and the controller only wires up the interactive bits (clicks, fetches, DOM toggles). New to Stimulus? Read a controller top-to-bottom: its `static targets`/`values` name the DOM it touches, and its action methods are what the HTML calls.

They group by the surface they drive. This is the shape, not an exhaustive list — open the directory for the current set:

- **Map** — `map_controller` is the largest. It owns the Mapbox GL JS instance (its own DOM, so it's *not* a Turbo Frame): the vector-tile source at `/tiles/:z/:x/:y`, click-to-open-a-system, geocoder fly-to, and re-applying the polygon/`pwsid` filter when filters change.
- **Filters** — `filter_controller` orchestrates Apply/Reset (see [Turbo Patterns](#turbo-patterns) for the flow it drives); `slider_controller` is the dual-handle range slider that fetches histogram bins; `bwn_filter_controller` state-gates the Boil water notices filter row (see [FILTERING.md](FILTERING.md)); `filter_layout_controller` / `filter_menu_controller` handle responsive tab collapse and menu open/close.
- **Table** — `table_frame_controller`, `table_search_controller`, `manage_columns_controller` (the column picker), and `row_selection_controller` (checkbox selection feeding exports).
- **Panels & overlays** — `report_controller` (full-screen system report), `sidebar_controller`, `nav_controller` (Map ↔ Table view switch), `tooltip_controller`.
- **Datasets & exports** — `datasets_controller` / `dataset_card_controller` (the datasets browse view), `export_controller` (CSV / GeoJSON download of the current filter params), `clipboard_controller`.

The one cross-controller contract worth knowing: **filters flow through a shared singleton**, `app/javascript/filter_state.js`. `filter_controller` writes it; `map_controller`, `export_controller`, and the stats/table frames read it. That's what keeps the map, stats bar, and table showing the same filter set. See [Turbo Patterns](#turbo-patterns).

---

## Turbo Patterns

The main app page (`home/index`) uses Turbo Frames to update independent sections without full page reloads.

```
┌─────────────────────────────────────────────────────┐
│  Filter Bar (Turbo Frame: "filter-bar")             │
│  [Source] [Attributes] [Boundaries] [Compliance]... │
├─────────────────────────────────────────────────────┤
│                                                     │
│   Map (NOT a Turbo Frame — managed by Stimulus)     │
│                                                     │
│              ┌───────────────────────┐              │
│              │ Detail Panel          │              │
│              │ (Turbo Frame:         │              │
│              │  "system-detail")     │              │
│              └───────────────────────┘              │
│                                                     │
├─────────────────────────────────────────────────────┤
│  Stats Bar (Turbo Frame: "stats-bar")               │
│  Showing 1,234 systems | 2.3M people served | ...   │
├─────────────────────────────────────────────────────┤
│  Data Table (Turbo Frame: "data-table")             │
│  Sortable, paginated, server-rendered               │
└─────────────────────────────────────────────────────┘
```

**Key pattern:** The map is **not** inside a Turbo Frame — Mapbox GL JS manages its own DOM and state, so it can't be swapped like HTML.

**What happens on Apply.** There is no form submit. `filter_controller` is the single orchestrator: it reads the filter DOM, writes the shared `FilterState` (a JS singleton, `app/javascript/filter_state.js`), and then refreshes the three surfaces — each by a different mechanism, only one of which is event-based:

```
User clicks Apply
  └── filter_controller.apply()
        ├── writes FilterState (shared singleton) + syncs the URL
        ├── dispatches "filters:changed" ─────────→ map_controller re-fetches GET /map,
        │                                            then map.setFilter() re-renders tiles
        │                                            (the map is the ONLY listener)
        ├── syncStatsFrame() sets the stats-bar ──→ Turbo loads GET /public_water_systems/stats
        │   <turbo-frame> src                        and swaps the stats bar in place
        └── Turbo.visit(/table, { frame }) ───────→ Turbo loads GET /table
                                                     and swaps the table rows in place
```

The stats and table refreshes are **direct calls**, not reactions to `filters:changed` — only the map listens for that event. Each frame updates independently with no full-page reload.

---

## Tile Generation

The tile endpoint replaces `wdt_mvt.php`. The approach is the same: PostGIS generates MVT tiles on-demand, cached in the `tile_cache` table.

### Layer Strategy

The legacy app generates **15 separate layers** per tile, each with a different data join (violations, demographics, funding, etc.). This was necessary because the client-side filter logic needed all properties baked into the tiles.

With server-side filtering, tiles need far fewer properties. The primary tile layers are:

| Layer | Purpose | Properties |
|-------|---------|------------|
| `pws` | Service area polygons | `pwsid`, `stusps`, core display fields |
| `places` | Census place boundaries | `geoid`, `name`, `place_pwsids` |
| `counties` | County boundaries | `geoid`, `name` |
| `states` | State boundaries | `geoid`, `stusps`, `name` |

Filtered highlighting happens client-side: the filter API returns a list of matching `pwsid` values, and the map controller applies a Mapbox GL JS filter like `["in", "pwsid", ...matchingIds]` to style matching vs. non-matching systems.

### Zoom-dependent simplification

Geometries are simplified at lower zoom levels for performance (same approach as legacy):

| Zoom | Simplification tolerance |
|------|-------------------------|
| ≤ 4 | 0.05 |
| 5 | 0.01 |
| 6 | 0.005 |
| 7 | 0.001 |
| 8 | 0.0005 |
| 9 | 0.0001 |
| 10 | 0.00005 |
| 11 | 0.00001 |
| 12+ | 0 (no simplification) |

### Cache invalidation

See **[TILE_CACHE.md](TILE_CACHE.md)** for the full explanation of selective refresh vs. full bust+warm, which importers trigger which, and when a manual bust is required (code changes to what a tile embeds, not just data changes).

---

## Background Jobs

### `EtlImportJob`

SolidQueue recurring job. Runs the full ETL pipeline:

1. Issue HTTP HEAD requests against source files under `ETL_SOURCE_URL`
2. Compare `Last-Modified` timestamps against the `data_imports` table
3. Download and import changed files
4. Run scoped post-import steps for changed geometry
5. Refresh affected tile cache rows through `tile_refresh` jobs

See [ETL.md](ETL.md) for full pipeline details.

### `TileCacheWarmJob` / `TileCacheRefreshJob`

See **[TILE_CACHE.md](TILE_CACHE.md#pre-warming-tilecachewarmjob)** — full pre-warm vs. targeted selective refresh, on the `tile_warm` and `tile_refresh` queues respectively.
