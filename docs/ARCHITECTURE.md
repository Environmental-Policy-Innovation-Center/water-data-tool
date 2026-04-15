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

```
app/
├── controllers/
│   ├── home_controller.rb                   # root HTML page (GET /) + DataTables SSP (GET /table)
│   ├── public_water_systems_controller.rb   # REST API: index (filter), show, export
│   ├── tiles_controller.rb                  # MVT tile endpoint
│   ├── reports_controller.rb                # printable system report
│   ├── places_controller.rb                 # place autocomplete search (GET /places/search)
│   └── [pages_controller.rb]                # planned for M12: datasets, downloads, static pages
├── models/
│   ├── public_water_system.rb               # central model (pwsid PK)
│   ├── service_area_geometry.rb
│   ├── demographic.rb
│   ├── violations_summary.rb
│   ├── environmental_justice.rb
│   ├── funding_summary.rb
│   ├── watershed_hazard.rb
│   ├── boil_water_summary.rb
│   ├── trend_datum.rb
│   ├── tile_cache.rb
│   ├── data_import.rb
│   ├── place_system_crosswalk.rb
│   ├── cartographic_state.rb
│   ├── cartographic_county.rb
│   └── cartographic_place.rb
├── models/concerns/
│   ├── filterable.rb                        # filter scopes for PublicWaterSystem
│   └── exportable.rb                        # CSV/GeoJSON generation
├── jobs/
│   ├── etl_import_job.rb                    # SolidQueue: full ETL pipeline
│   └── tile_cache_warm_job.rb               # SolidQueue: pre-generate common tiles
├── javascript/
│   └── controllers/                         # Stimulus controllers
│       ├── map_controller.js                # Mapbox GL JS init, tile loading, click
│       ├── filter_controller.js             # filter form submit/reset, URL sync
│       ├── slider_controller.js             # range slider with histogram
│       ├── table_controller.js              # DataTables SSP wiring, pagination, sorting
│       ├── export_controller.js             # CSV/GeoJSON download trigger
│       ├── nav_controller.js                # map/table/section view toggle
│       ├── place_autocomplete_controller.js # debounced place search dropdown
│       └── report_controller.js             # report overlay open/close
├── views/
│   ├── home/
│   │   ├── index.html.erb                   # root page — map view, table, all UI sections
│   │   ├── _filter_menus.html.erb           # filter dropdown menus partial
│   │   └── _sidebar.html.erb               # left sidebar partial
│   ├── public_water_systems/
│   │   ├── show.html.erb                    # system detail panel (HTML format)
│   │   └── sections/                        # 8 partials for detail sections
│   │       ├── _overview.html.erb
│   │       ├── _demographics.html.erb
│   │       ├── _environmental_justice.html.erb
│   │       ├── _violations.html.erb
│   │       ├── _funding.html.erb
│   │       ├── _watershed_hazards.html.erb
│   │       ├── _boil_water.html.erb
│   │       └── _trends.html.erb
│   ├── reports/
│   │   └── show.html.erb                   # printable report
│   └── layouts/
│       └── application.html.erb
└── assets/
    └── stylesheets/
        └── application.tailwind.css

config/
├── routes.rb
├── database.yml
└── initializers/
    └── solid_queue.rb

db/
├── migrate/                                 # schema migrations
└── seeds.rb

lib/
└── tasks/
    ├── etl.rake                             # bin/rails etl:import
    └── seed_states.rake                     # bin/rails db:seed:states[VT,RI]

spec/
├── models/                                  # model specs (scopes, associations)
├── requests/                                # request specs (controller integration)
├── system/                                  # system specs (Capybara, critical flows)
├── jobs/                                    # job specs (ETL pipeline)
├── factories/                               # FactoryBot factories
├── support/
│   └── shoulda_matchers.rb
├── rails_helper.rb
└── spec_helper.rb
```

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

Serves the root page and the DataTables SSP endpoint. These are unrelated responsibilities that
share a controller because neither belongs cleanly elsewhere.

- **`index`** — renders `home/index.html.erb`, the main app page (map, filter bar, table, all UI).
  Also queries `DataImport.maximum(:imported_at)` for the "last updated" display.
- **`table`** — `GET /table.json`. DataTables server-side processing endpoint. Accepts DataTables
  protocol params (`draw`, `start`, `length`, `order[0][column]`, `order[0][dir]`). Applies the
  same `Filterable#apply_filters` logic and returns the DataTables response envelope
  (`draw`, `recordsTotal`, `recordsFiltered`, `data`).

> Note: `HomeController` was not in the original architecture plan — the plan assumed
> `PublicWaterSystemsController#index` would dual-respond to HTML and JSON. In practice, the
> root view and the DataTables SSP protocol both needed a home, so `HomeController` emerged
> organically. Both approaches are valid Rails; `HomeController` is idiomatic for a root page.

### `PublicWaterSystemsController`

REST API for filter, detail, and export. Does not serve the root HTML page.

- **`index`** — accepts filter params, applies scopes via `Filterable` concern, returns JSON with
  `{total_count, page, per_page, results, summary}`. The `summary` key includes aggregate stats
  (systems count, total population, open violations, average MHI) computed in one SQL query.
- **`show`** — loads a single system with all associations. Returns JSON or HTML (the detail panel
  rendered in a Turbo Frame on map click, or as a standalone page).
- **`export`** — same filter logic as `index`, returns CSV or GeoJSON file download.
- **`stats`** *(M7 — planned)* — returns aggregate summary stats as a Turbo Frame HTML partial
  for the stats bar overlay.

### `TilesController`

- **`show`** — receives `z/x/y` params, checks `TileCache`, generates MVT via PostGIS `ST_AsMVT`
  on cache miss, returns binary protobuf with `Content-Type: application/x-protobuf`.

### `ReportsController`

- **`show`** — printable report for a single system. Full-page HTML layout optimized for print.
  Loads into a full-screen overlay via Turbo Frame on "View Full Report" click.

### `PlacesController`

- **`search`** — `GET /places/search?q=...`. Prefix ILIKE match against `cartographic_places`.
  Returns up to 10 `{geoid, name, stusps}` results as JSON. Used by `place_autocomplete_controller.js`.
  1-hour cache headers.

### `PagesController` *(planned — M12)*

Not yet built. Will serve:
- **`datasets`** — describes source datasets.
- **`downloads`** — lists pre-built S3 zip download links.

---

## Filter Architecture

Filters flow from URL params through the `Filterable` concern to SQL scopes. The concern lives on `PublicWaterSystem` and provides a single entry point:

```ruby
# app/models/concerns/filterable.rb
module Filterable
  extend ActiveSupport::Concern

  class_methods do
    def apply_filters(params)
      scope = all

      # Categorical filters (AND between groups, OR within)
      scope = scope.where(gw_sw_code: params[:gw_sw_code]) if params[:gw_sw_code].present?
      scope = scope.where(owner_type: params[:owner_type]) if params[:owner_type].present?
      scope = scope.where(primacy_type: params[:primacy_type]) if params[:primacy_type].present?
      scope = scope.where(service_area_type: params[:service_area_type]) if params[:service_area_type].present?
      scope = scope.where(pop_cat_5: params[:pop_cat_5]) if params[:pop_cat_5].present?

      # Boolean filters
      scope = scope.where(is_wholesaler: true) if params[:is_wholesaler] == "true"
      scope = scope.where(is_school_or_daycare: true) if params[:is_school_or_daycare] == "true"
      scope = scope.where(source_water_protection_code: "Yes") if params[:has_source_protection] == "true"
      scope = scope.where(open_health_viol: "Yes") if params[:has_open_violations] == "true"

      # Range filters (min/max pairs)
      scope = scope.where("area_sq_miles >= ?", params[:area_min]) if params[:area_min].present?
      scope = scope.where("area_sq_miles <= ?", params[:area_max]) if params[:area_max].present?

      # Geographic filters
      scope = scope.where(stusps: params[:state]) if params[:state].present?

      # ... violation range filters via joins to violations_summaries
      # ... demographic range filters via joins to demographics
      # ... and so on for each filter group

      scope
    end
  end
end
```

**Combination logic:**
- **Between filter groups:** AND (a system must match all active filter groups)
- **Within a filter group:** OR for multi-select (e.g., `owner_type[]=Federal&owner_type[]=State` matches either)
- **Range filters:** AND (min AND max must both be satisfied)

---

## Stimulus Controllers

### `map_controller.js`

The largest Stimulus controller. Manages the Mapbox GL JS map instance.

**Responsibilities:**
- Initialize Mapbox GL JS with the project's style
- Add vector tile source pointing to `/tiles/:z/:x/:y`
- Handle map click → load system detail in Turbo Frame
- Geocoder result → context-aware flyTo (state → z5, county → z7, city → z8)
- Alaska/Hawaii quick-zoom buttons

### `filter_controller.js`

Manages the filter dropdown menus.

**Responsibilities:**
- Toggle filter menus open/close; dismiss on outside click
- Collect DOM filter state on Apply → write to `FilterState` → dispatch `filters:changed`
- Reset all filter inputs to defaults on Reset
- Serialize active filters to URL query params (`replaceState`) for shareable URLs
- Restore filter state from URL on page load
- Track active filter count per group (badge display)

### `nav_controller.js`

Handles view switching between Map and Table modes, and sidebar navigation.

**Responsibilities:**
- Show/hide `#container-map`, `#container-table`, `#container-datasets`, etc.
- Toggle active state on nav items
- Dispatch `table:show` event when Table view is activated (triggers DataTables init)

### `table_controller.js`

Wires DataTables server-side processing to `GET /table.json`.

**Responsibilities:**
- Initialize DataTables with SSP config on `table:show` event
- Pass current `FilterState` params on each AJAX request
- Reload DataTables (and stats bar) on `filters:changed`

### `export_controller.js`

**Responsibilities:**
- Trigger CSV or GeoJSON download by submitting current filter params to the export endpoint

### `place_autocomplete_controller.js`

Debounced place search used inside the Boundaries filter menu.

**Responsibilities:**
- Fetch `/places/search?q=...` with 300ms debounce
- Render XSS-safe dropdown of results
- On selection: populate hidden `place_geoid` field, dispatch `filters:changed`

### `report_controller.js`

**Responsibilities:**
- Open/close the full-screen report overlay (`#container-report`)
- Wire print and close buttons

### `slider_controller.js`

Range slider with optional histogram overlay (planned for area/density filters — deferred from M6).

**Responsibilities:**
- Render dual-handle min/max range inputs
- Display histogram of data distribution
- Update hidden form fields with selected range

---

## Turbo Patterns

The main app page (`public_water_systems/index`) uses Turbo Frames to update independent sections without full page reloads.

```
┌─────────────────────────────────────────────────────┐
│  Filter Bar (Turbo Frame: "filter-bar")             │
│  [Source] [Attributes] [Boundaries] [Compliance]... │
├─────────────────────────────────────────────────────┤
│                                                     │
│   Map (NOT a Turbo Frame — managed by Stimulus)     │
│                                                     │
│              ┌───────────────────────┐               │
│              │ Detail Panel          │               │
│              │ (Turbo Frame:         │               │
│              │  "system-detail")     │               │
│              └───────────────────────┘               │
│                                                     │
├─────────────────────────────────────────────────────┤
│  Stats Bar (Turbo Frame: "stats-bar")               │
│  Showing 1,234 systems | 2.3M people served | ...   │
├─────────────────────────────────────────────────────┤
│  Data Table (Turbo Frame: "data-table")             │
│  Sortable, paginated, server-rendered               │
└─────────────────────────────────────────────────────┘
```

**Key pattern:** The map is **not** inside a Turbo Frame. Mapbox GL JS manages its own DOM and state. When filters change, the filter form submits via Turbo, which replaces the stats bar and table frames. The map controller listens for the Turbo response and updates its layer filters accordingly.

---

## Tile Generation

The tile endpoint replaces `wdt_mvt.php`. The approach is the same: PostGIS generates MVT tiles on-demand, cached in the `tile_cache` table.

### Layer Strategy

The legacy app generates **15 separate layers** per tile, each with a different data join (violations, demographics, funding, etc.). This was necessary because the client-side filter logic needed all properties baked into the tiles.

With server-side filtering, tiles need far fewer properties. The primary tile layers are:

| Layer | Purpose | Properties |
|-------|---------|------------|
| `pws` | Service area polygons | `pwsid`, `stusps` |
| `pws_points` | Point centroids (ensures visibility at low zoom) | `pwsid`, `stusps`, core display fields |
| `places` | Census place boundaries | `geoid`, `name`, `place_pwsids` |
| `counties` | County boundaries | `geoid`, `name`, `county_pwsids` |
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

After an ETL import, truncate the `tile_cache` table (or delete specific layers if only some source tables changed).

---

## Background Jobs

### `EtlImportJob`

SolidQueue recurring job. Runs the full ETL pipeline:

1. Fetch S3 manifest (`data.json`)
2. Compare timestamps against `data_imports` table
3. Download and import changed files
4. Run post-import steps
5. Invalidate tile cache

See [ETL.md](ETL.md) for full pipeline details.

### `TileCacheWarmJob`

Optional. After an ETL import, pre-generates tiles for common zoom levels (z0–z7, covering the continental US viewport) so the first user after a data update doesn't hit cold tiles.

---

## Testing Strategy

| Layer | Tool | Focus |
|-------|------|-------|
| Models | RSpec + Shoulda Matchers | Filter scopes, associations, validations |
| Requests | RSpec request specs | Filter params produce correct results, response shapes, pagination |
| System | RSpec + Capybara | Critical user flows: filter → map update → table update |
| Jobs | RSpec | ETL pipeline: CSV parsing, type casting, post-import steps |
| Factories | FactoryBot | Test data generation for all models |

Use FactoryBot factories with realistic data from a small state subset. Shoulda Matchers for declarative association and validation testing.

---

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  root "home#index"
  get "/table", to: "home#table", as: :table          # DataTables SSP

  get "/tiles/:z/:x/:y", to: "tiles#show", as: :tile,
      constraints: {z: /\d+/, x: /\d+/, y: /\d+/}

  get "/places/search", to: "places#search"            # place autocomplete

  resources :reports, param: :pwsid, only: [:show]    # printable report

  resources :public_water_systems, param: :pwsid, only: %i[index show] do
    collection do
      get :export
      get :stats  # planned M7: aggregate stats for stats bar Turbo Frame
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```
