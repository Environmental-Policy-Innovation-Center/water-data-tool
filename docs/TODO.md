# TODO

Engineering notes on known gaps and future improvements.
These are not milestones — see ROADMAP.md for planned feature work.

---

## Work Order

1. ~~**Extract Non-RESTful Controller Actions** — Move `stats` and `export` actions to dedicated `StatsController` and `ExportsController`; extract `row_for` serialization to `PublicWaterSystemTableSerializer`~~
2. **Standardize DB ENV Var Prefixes** — Ensure all DB-related environment variables consistently use the `DB_` prefix
3. **ETL Field Mapping Validation** — Build post-import audit specs that assert expected distinct values per filterable column, catching silent data quality bugs before they surface as broken filters

- ~~Dev Seed Data — Filter Coverage Gaps (add Ohio or similar to cover wholesaler/school filters)~~ Default seed now includes OH, CO, PR alongside VT + RI — verify `is_wholesaler` and `is_school_or_daycare` counts after first seed run
- Map — State click should update stats bar with counts for that state. Legacy app filtered the stats panel to the clicked state even without any other filters active. V2 draws the border outline on click but does not update stats — clicking a state on the map feels like it does nothing data-wise. Fix: clicking a state should apply a state boundary filter (or trigger a stats refresh scoped to that state).
- Add Lograge gem to help silence noisy logs
- Filter UI — `has-filter` green highlight on active filter buttons
- Filter UI — Verify badge counts match legacy behavior
- Filter UI — More dropdown expand/collapse sub-filters (violations + watershed hazards)
- Styling — Map ocean/water color slightly too dark
- Filter Parity — Demographic & Environmental Justice range sliders (largest UI gap)
- Filter Parity — EJScreen Drinking Water Score (needs backend wiring + UI)
- Filter Parity — Water Source Sub-type checkboxes
- Filter Parity — Annual Water and Sewer Bill bucket picker
- Observability — ETL import job failure alerting (important before non-technical handoff)
- Frontend Modernization — Replace DataTables with Turbo Frame table *(on hold)*
- Frontend Modernization — Replace place autocomplete `fetch()` with Turbo Frame *(on hold)*
- Frontend Modernization — Activate Tailwind and migrate custom CSS *(on hold)*
- Export UX — Test CSV and GeoJSON downloads against a large dataset (e.g. full national or a large state). If generation takes more than ~2–3 seconds, add a spinner/disabled-button state to `export_controller.js` to indicate work in progress. The legacy app had no spinner; this is only needed if server-side generation time is noticeable.
- Map Filter Scale — The current filter→map approach fetches matching pwsids from `GET /map` and spreads them into a Mapbox GL `["in", "pwsid", ...]` filter expression. This works well at state scale but may hit expression size limits or cause noticeable latency at national scale (tens of thousands of systems). If that proves to be the case, the architectural fix is to pass filter params directly into the tile URL so `TilesController` applies `apply_filters` during MVT generation — eliminating the pwsid fetch entirely. That approach would require tile cache keys to include filter params (or bypass the cache for filtered requests).
- ~~Tile Cache Warm Depth — `TileCacheWarmJob` now warms z0–z8 using US region bounding boxes (continental US, AK, HI, PR, Guam+CNMI), skipping empty ocean/land tiles. 96.5% reduction vs blind z0–z8 approach (3,213 coords vs ~349k). z9 generates on-demand (fast). See `scratch/performance_work.md` for full metrics.~~
- Other — Ensure Mapbox token is not exposed in browser devtools
- Other — Add pending migration warning on console/server/spec startup
- Other — Add `simplecov` and `lefthook` gems
- Other — Home page "Last Updated On" display

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

## ~~Controller Refactoring — Non-RESTful Actions~~ ✓ DONE

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
| `owner_type = "Native American"` (UI: "Tribal") | 0 | VT/RI have no tribally-owned systems |

**Fix:** The default seed now includes OH, CO, and PR alongside VT and RI. After first seed run, verify:

```ruby
PublicWaterSystem.where(is_wholesaler: true).count        # expect > 0 (OH)
PublicWaterSystem.where(is_school_or_daycare: true).count # expect > 0 (OH)
PublicWaterSystem.where(primacy_type: "Tribal").count     # expect > 0 (CO has Ute tribal systems)
PublicWaterSystem.where(primacy_type: "Territory").count  # expect > 0 (PR)
```

If any are still 0, try adding California (`CA`) to the seed.

**Priority:** Low — affects dev/testing only, not production.

---

## Filter UI — Minor Parity Items

Small behavioral gaps from the legacy app that remain unaddressed.

---

### Attributes Filter — New Filters Need Verification

V2 added four filters not present in legacy: Wholesaler, School or daycare, Tribal (owner), and Territory (primacy). These are wired to the backend but have not been verified against expected behavior in production data. The VT/RI dev seed returns zero results for all four (see Dev Seed Data section below), so testing requires production data or a richer seed state.

**Priority:** Low — verify before public launch.

---

### Filter Button Badge — `has-filter` Green Highlight

- **Legacy:** Filter button links receive a `has-filter` CSS class when their group has active filters, producing a green highlight
- **V2:** Badge counts show correctly but `has-filter` is never applied — buttons don't turn green when filters are active
- **What to do:** In `#updateBadges`, add/remove `has-filter` on the `.filter-menu-btn` `<a>` for each group based on whether its count is > 0
- **Priority:** Low — cosmetic, does not affect functionality

---

### Filter Badge Counts — Verify Match with Legacy

- **Legacy:** Used a `filterGroupCounts` object to track counts per group
- **V2:** Counts active param keys per group using a hardcoded key list in `#updateBadges`
- **What to verify:** Spot-check each filter group (Source, Attributes, Boundaries, Compliance, Population, More) with known filter combinations and confirm V2 badge counts match what legacy showed
- **Priority:** Low — verify before public launch

---

### More Dropdown — Expand/Collapse Sub-filters

- **Legacy:** Three items expand into sub-filters when checked: "Health violations in last 5 years" and "Health violations in last 10 years" (each with 10 violation sub-types + range sliders), and "Potential Watershed Hazards" (5 sub-types). "Annual water and sewer bill" also expands into a rate tier picker.
- **V2:** None of these expand/collapse behaviors exist. Violations only have top-level checkboxes; watershed hazards are flat individual checkboxes; financial is disabled.
- **What to do:** Build the parent→child expand/collapse UI pattern for violations and watershed hazards. Violations sub-type range filters would also need new backend work.
- **Priority:** Low — significant UI work; backend range filters for watershed hazards already exist

---

## Filter Parity Gaps — Legacy vs V2

Filters present in the legacy app that are missing from the V2 UI. Backend filter logic is noted for each.

---

### Population — Demographic & Environmental Justice Filters *(largest gap)*

The legacy Population filter had a full demographic panel with histogram range sliders. V2 only shows size categories and density. All of the following have range filters (`_min`/`_max`) already wired in `Filterable` and data in the `demographics` or `environmental_justices` tables — this is purely a UI gap.

**Trend data** (wired: `trend_data` table, `population_pct_change`, `mhi_pct_change`):
- Change in people served (last 10 years)
- Change in median household income (last 10 years)

**Demographic data** (wired: `demographics` table):
- Households below the poverty line (`poverty_rate`)
- Unemployment (`unemployment_rate`)
- Annual median household income (`median_household_income`)
- Higher education attainment (`bachelors_degree_rate`)
- Children under 5 (`age_under_5_rate`)
- Elderly over 61 (`age_over_61_rate`)
- People of color (`poc_rate`)
- Race/ethnicity breakdowns: White, Black, Asian, American Indian & Alaskan Native, Native Hawaiian & Pacific Islander, Latino/a, Other, Mixed race

**Environmental justice** (wired: `environmental_justices` table):
- Disadvantaged area / CEJST (`cejst_disadvantaged_pct`)
- Social Vulnerability Index (`svi_overall_pctl`)
- Climate Vulnerability Index (`cvi_overall_score`)

**Note:** Legacy used histogram sliders for all of these. The V2 slider infrastructure exists (`slider_controller.js`) but none of these fields are surfaced in the Population filter UI.

**Priority:** Medium — significant feature gap, but requires substantial UI work. Backend is ready.

---

### Compliance — EJScreen Drinking Water Score

- **Legacy:** "2024 EJScreen Score" checkbox in the Compliance filter
- **V2:** Column `ejscreen_drinking_water` exists in the `demographics` table but no filter param is wired in `Filterable` and no UI exists
- **Priority:** Low — needs both backend filter wiring and UI

---

### Source — Water Source Sub-types

- **Legacy:** The Source filter had granular sub-type checkboxes under Ground (purchased, non-purchased, surface-influenced) and Surface (purchased, non-purchased)
- **V2:** Only the top-level Both/Ground/Surface radio buttons exist; `gw_sw_code` is a single-value filter, not multi-select
- **Priority:** Low — adds precision but the top-level radios cover the common cases

---

### Financial — Annual Water and Sewer Bill

- **Legacy:** Expanded into a bucket picker with 7 dollar-range tiers (< $125 through > $1000), filtering on `most_common_rate_tidy`
- **V2:** `most_common_rate_tier` column exists in `demographics` and is partially wired in `Filterable`, but the bucket picker UI is not built and the data values need to be confirmed. Shown in the UI as disabled / TBD.
- **Priority:** Low — needs data value audit + bucket picker UI

---

## Styling

- Map ocean/water color is slightly too dark compared to legacy — lighten the water layer paint override on the `light-v11` Mapbox style

---

## Other

- Ensure Mapbox access token is not exposed in request/response data visible in browser devtools
- Add a warning when opening the Rails console, running specs, or starting the server if there are pending migrations
- Add gems: `simplecov`, `lefthook`
- Home Page - add `Last Updated On:` and calculation logic
- ETL Source Data — confirm with the EPIC data team that `ETL_SOURCE_URL` in staging and production points to the correct S3 folder (production data, not test data); verify `is_wholesaler`, `is_school_or_daycare`, and `primacy_type = "Tribal"` are non-zero after the first ETL run against production data.

