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

**What:** Currently we have divergence in Environment Variable naming patterns for ENV Vars that relate to the DB.

**Why:** For consistency and convention, all of these ENV Vars related to Database stuff should be prepended with `DB_`

**Where:** TBD

**Options:**
- TBD

**Priority:** TBD


---

## Controller Refactoring — Non-RESTful Actions

**What:** Two actions in `PublicWaterSystemsController` sit outside the standard 7 REST actions, and `HomeController` contains serialization logic that belongs in a serializer.

**Why:** Convention is to limit controller actions to the standard 7 and keep serialization out of controllers.

**Note on `HomeController#table`:** `HomeController` owning both `#index` (app shell/map) and `#table` (table data feed) is intentionally coherent — the map and table are two views of the same home page, not separate resources. `#table` stays in `HomeController`. `PlacesController#search` is also acceptable as-is.

### `PublicWaterSystemsController#stats` — extract to `StatsController#show`

- Add `resource :stats, only: :show` to routes; remove `get :stats` from the `public_water_systems` collection block
- Update `frame.src` URL in `table_controller.js#reloadStatsFrame` from `/public_water_systems/stats` to `/stats`
- `build_summary` is currently a private method shared between `#index` and `#stats` — move it to a model class method `PublicWaterSystem.build_summary(scope, count)` so both controllers can call it without duplication

### `PublicWaterSystemsController#export` — extract to `ExportsController#show`

- Add `resource :export, only: :show` to routes; remove `get :export` from the `public_water_systems` collection block
- Update the export URL in `export_controller.js`
- Private render helpers `render_csv_export` and `render_geojson_export` move into `ExportsController` as private methods — the real work is already in `PublicWaterSystemExporter`

### `HomeController` — extract `row_for(pws)` to a serializer

`row_for(pws)` is serialization logic and does not belong in a controller. Extract to `PublicWaterSystemTableSerializer`, following the `PublicWaterSystemSerializer` / `PublicWaterSystemDetailSerializer` pattern already in `app/serializers/`. `HomeController#table` would call `PublicWaterSystemTableSerializer.new(pws).serialize`.

Private controller methods `filter_params`, `apply_search`, `order_clause`, and `datatable_response` are controller-layer concerns and stay as private methods in `HomeController`.

**Priority:** Low — no functional impact, purely structural.

---

## Replace AJAX with Turbo (Hotwire Alignment)

**What:** Two places in the app use non-Turbo fetch patterns. The conventional Rails 8 / Hotwire replacement for both is Turbo Frames.

**Why:** Hotwire exists to replace AJAX. These are the two remaining carry-overs from pre-Hotwire patterns.

### 1. DataTables (`table_controller.js` → `HomeController#table`)

DataTables uses jQuery's internal AJAX to call `/table.json` with a specific SSP protocol (`draw`, `recordsTotal`, `recordsFiltered`, `data`). This is a jQuery-era pattern incompatible with Hotwire.

**Hotwire replacement:** Replace DataTables with a Turbo Frame table. Pagination, sorting, and filtering trigger Turbo Frame requests that re-render a `_table.html.erb` partial server-side. The entire `HomeController#table` action and its JSON SSP format (`datatable_response`, `order_clause`, `apply_search`, `filter_params`) would be replaced by a standard `#index`-style action rendering HTML. `row_for` / the table serializer would also be eliminated in favour of a server-rendered partial.

**Impact:** Significant. DataTables provides built-in sorting UI, pagination, and search that must be rebuilt in ERB/Tailwind/Stimulus. `filter_state.js` (currently bridges filter state to the DataTables AJAX call) may be eliminated or simplified. This is the largest remaining architectural debt in the app.

**Files affected:** `table_controller.js`, `HomeController`, `home/index.html.erb`, `filter_state.js`, routes.

### 2. Place autocomplete (`place_autocomplete_controller.js` → `PlacesController#search`)

Uses native `fetch()` to call `/places/search?q=` and manually builds DOM from the JSON response.

**Hotwire replacement:** The input triggers a Turbo Frame GET to `/places/search?q=`; the server renders a `_results.html.erb` partial inside the frame. No `fetch()`, no manual DOM manipulation. `PlacesController#search` renders HTML instead of JSON.

**Impact:** Moderate. `place_autocomplete_controller.js` would be significantly simplified or eliminated. Requires a new `places/search.html.erb` partial.

**Files affected:** `place_autocomplete_controller.js`, `PlacesController`, new `places/_results.html.erb`, `home/index.html.erb` autocomplete markup.

**Priority:** Medium. DataTables is the larger of the two and should be tackled as its own milestone.

---

## Stats Bar — Nil Area Median Income Display
_(may already be fixed - confirm)_

**What:** When no demographic records exist for the filtered set, `avg_median_household_income` is `nil`. The view renders just `~` (a bare tilde) because `number_to_currency(nil)` returns nil and the tilde is hardcoded before the ERB tag.

**Why:** `~` alone is meaningless to a user. Should render `N/A` to indicate data is unavailable.

**Where:** `app/views/public_water_systems/stats.html.erb` line 9:
```erb
# current (broken for nil):
~<%= number_to_currency(@summary[:avg_median_household_income], precision: 0) %>

# fix:
<%= @summary[:avg_median_household_income] ? "~#{number_to_currency(@summary[:avg_median_household_income], precision: 0)}" : "N/A" %>
```

Update the spec in `spec/requests/public_water_systems_spec.rb` ("renders a bare tilde...") to assert `include("N/A")` instead once fixed.

**Priority:** Low — cosmetic, but confusing in production when many systems lack demographic data.

---

## Other
- make sure tokens (Mapbox Api token) are not broadcasted in request/response data _(dev tools)_
- warning when trying to open console, run specs, start server, if there are pending migrations
- add gems: simplecov, lefthook