# TODO

Engineering notes on known gaps and future improvements.
These are not milestones — see ROADMAP.md for planned feature work.

---

## Observability

**What:** Proactive alerting when `EtlImportJob` fails after all retries are exhausted.

**Why:** Failures are currently logged and visible in SolidQueue's failed jobs queue, but nothing actively notifies anyone. A failed nightly import could go unnoticed until someone manually checks.

**Where:** `app/jobs/etl_import_job.rb` — add an `after_discard` callback, or a SolidQueue failure hook.

**Options:**
- `retry_on` + `discard_on` with an `after_discard` block that sends email/Slack
- A SolidQueue recurring job that checks for stale `data_imports` records (no successful import in N hours)
- External uptime/alerting service monitoring job health

**Priority:** Low for MVP — important before handing off to a non-technical team.

---

## ENV Var Consistency

**What:** DB-related environment variable names are inconsistent — some are prefixed with `DB_`, others are not.

**Why:** All DB-related ENV vars should be prefixed with `DB_` for clarity and convention.

**Priority:** Low — no functional impact, purely organizational.

---

## Controller Refactoring — Non-RESTful Actions

**What:** Two actions in `PublicWaterSystemsController` sit outside the standard 7 REST actions, and `HomeController` contains serialization logic that belongs in a serializer.

**Why:** Convention is to limit controller actions to the standard 7 and keep serialization out of controllers.

**Note on `HomeController#table`:** `HomeController` owning both `#index` (app shell/map) and `#table` (table data feed) is intentionally coherent — the map and table are two views of the same home page, not separate resources. `#table` stays in `HomeController`. `PlacesController#search` is also acceptable as-is.

### `PublicWaterSystemsController#stats` → `StatsController#show`

- Add `resource :stats, only: :show` to routes; remove `get :stats` from the `public_water_systems` collection block
- Update `frame.src` URL in `table_controller.js#reloadStatsFrame` from `/public_water_systems/stats` to `/stats`
- `build_summary` is currently a private method in `PublicWaterSystemsController` — move it to a model class method `PublicWaterSystem.build_summary(scope)` so both controllers can call it without duplication

### `PublicWaterSystemsController#export` → `ExportsController#show`

- Add `resource :export, only: :show` to routes; remove `get :export` from the `public_water_systems` collection block
- Update the export URL in `export_controller.js`
- Private render helpers `render_csv_export` and `render_geojson_export` move into `ExportsController` — the real work is already in `PublicWaterSystemExporter`

### `HomeController` — extract `row_for(pws)` to a serializer

`row_for(pws)` is serialization logic and does not belong in a controller. Extract to `PublicWaterSystemTableSerializer`, following the `PublicWaterSystemSerializer` / `PublicWaterSystemDetailSerializer` pattern already in `app/serializers/`. `HomeController#table` would call `PublicWaterSystemTableSerializer.new(pws).serialize`.

Private controller methods `filter_params`, `apply_search`, `order_clause`, and `datatable_response` are controller-layer concerns and stay as private methods in `HomeController`.

**Priority:** Low — no functional impact, purely structural.

---

## Frontend Modernization — Hotwire / Tailwind

**What:** The frontend was built incrementally and has significant carry-over from pre-Hotwire patterns. A full modernization pass would align the stack with Rails 8 / Hotwire conventions and activate Tailwind, which is already installed but unused.

**Why:** The app is a Rails 8 Hotwire app but the table, autocomplete, filter state management, and all styling predate Hotwire conventions. The result is more custom JavaScript and CSS than necessary, which increases maintenance cost and drift from Rails conventions over time.

---

### 1. Replace DataTables with a Turbo Frame Table *(largest item)*

DataTables uses jQuery's internal AJAX to call `/table.json` using the DataTables SSP protocol (`draw`, `recordsTotal`, `recordsFiltered`, `data`). This is a jQuery-era pattern.

**Hotwire replacement:** The table becomes a Turbo Frame. Pagination, sorting, and search trigger Turbo Frame GET requests that re-render a `_table.html.erb` partial server-side. `HomeController#table` and its JSON SSP envelope (`datatable_response`, `order_clause`, `apply_search`, `filter_params`) are replaced by a standard index-style action rendering HTML.

**Downstream simplifications:**
- `table_controller.js` is substantially simplified or eliminated
- `filter_state.js` (currently bridges filter state to the DataTables AJAX call) may be eliminated or reduced to a thin URL-sync utility
- `row_for(pws)` / `PublicWaterSystemTableSerializer` are eliminated in favour of a server-rendered partial
- `HomeController#table` and the `/table.json` route are removed

**Files affected:** `table_controller.js`, `filter_state.js`, `HomeController`, `home/index.html.erb`, routes.

**Priority:** High — this is the largest remaining architectural debt in the app and a prerequisite for meaningful Tailwind adoption on the table UI.

---

### 2. Replace Place Autocomplete `fetch()` with Turbo Frame

`place_autocomplete_controller.js` uses native `fetch()` to call `/places/search?q=` and manually builds DOM from the JSON response.

**Hotwire replacement:** The input triggers a Turbo Frame GET to `/places/search?q=`; the server renders a `_results.html.erb` partial inside the frame. No `fetch()`, no manual DOM manipulation. `PlacesController#search` renders HTML instead of JSON.

**Downstream simplifications:**
- `place_autocomplete_controller.js` is significantly simplified or eliminated
- `PlacesController#search` drops its JSON serialization path

**Files affected:** `place_autocomplete_controller.js`, `PlacesController`, new `places/_results.html.erb`, `home/index.html.erb` autocomplete markup.

**Priority:** Medium — standalone change, can be done before or after the DataTables replacement.

---

### 3. Activate Tailwind and Migrate Custom CSS

`tailwindcss-rails` is installed but has no `tailwind.config.js` and is not used anywhere. All styling lives in `app/assets/stylesheets/water_tool.css` using hand-authored custom class names.

**What this involves:**
- Create `tailwind.config.js` with content paths pointing to `app/views/**/*` and `app/javascript/**/*`
- Migrate `water_tool.css` custom classes to Tailwind utilities incrementally — prioritizing the table and filter UI first (highest churn areas), leaving the map chrome until last
- Remove `water_tool.css` entries as each section is migrated

**Note:** This is most valuable done in conjunction with the DataTables → Turbo Frame migration (item 1), since that rewrites the table markup from scratch anyway.

**Priority:** Low as a standalone task — high-value when bundled with item 1.

---

## ETL Import — Field Mapping Validation

**What:** No systematic verification that all ETL-imported fields are correctly mapped from source CSVs to the database. Field mapping bugs (wrong column name, wrong value transformation, silently null fields) are only discovered when a feature tries to use the data.

**Why:** The filter bugs found during M7 development — `gw_sw_code` sending `"GW"`/`"SW"` when the DB stores `"Groundwater"`/`"Surface Water"`, `service_area_type` using the wrong column (`symbology_field`), and `pop_cat_5` using index numbers instead of range strings — all trace back to assumptions about what the ETL puts in the DB that turned out to be wrong. There is currently no test or audit that catches this class of bug proactively.

**What to build:**
- A post-import audit task or spec that queries each filterable column and asserts expected distinct values are present (e.g., `gw_sw_code` contains `"Groundwater"` and `"Surface Water"`, not `"GW"`/`"SW"`)
- Coverage for boolean fields (`is_wholesaler`, `is_school_or_daycare`, `source_water_protection_code`) to confirm they are being set to `true`/`false` correctly rather than left nil
- Coverage for association tables (`demographics`, `violations_summaries`, etc.) — confirm record counts are non-zero and spot-check key columns for expected value formats

**Where:** `app/jobs/etl_import_job.rb`, `app/services/etl/` (or wherever ETL transformers live), potentially a new `spec/etl/` or `spec/tasks/` directory for integration-level ETL specs.

**Priority:** Medium — the risk is silent data quality bugs that make filters appear broken when the ETL is actually the root cause.

---

## Dev Seed Data — Filter Coverage Gaps

**What:** The VT + RI seed dataset (`bin/rails 'db:seed:states[VT,RI]'`) leaves two filters with zero matching records in development, so applying them returns an empty result set:

| Filter | Dev count | Reason |
|--------|-----------|--------|
| `is_wholesaler = true` | 0 | VT/RI have no wholesaler systems in SDWIS |
| `is_school_or_daycare = true` | 0 | VT/RI have no school/daycare systems flagged in SDWIS |

The following are absent for geographic reasons (not a bug, but worth knowing):

| Filter | Dev count | Reason |
|--------|-----------|--------|
| `primacy_type = "Tribal"` | 0 | VT/RI have no tribal primacy systems |
| `primacy_type = "Territory"` | 0 | VT/RI are not territories |
| `owner_type = "Tribal"` | 0 | VT/RI have no tribally-owned systems |

**Fix:** Add a state with richer system-type diversity to the dev seed. **Ohio is the recommended candidate** — it has a known wholesaler network and enough non-community systems to likely cover `is_school_or_daycare`. To test: `bin/rails 'db:seed:states[VT,RI,OH]'`, then verify with `PublicWaterSystem.where(is_wholesaler: true).count` and `PublicWaterSystem.where(is_school_or_daycare: true).count`.

If Ohio doesn't cover both, try California or Texas next.

**Priority:** Low — affects dev/testing only, not production.

---

## Other

- Ensure Mapbox access token is not exposed in request/response data visible in browser devtools
- Add a warning when opening the Rails console, running specs, or starting the server if there are pending migrations
- Add gems: `simplecov`, `lefthook`
- "More" filter dropdown on the homepage — needs additional filters wired up and the reset button enabled
