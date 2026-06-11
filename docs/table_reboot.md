# Table Row Selection & Export

> **Temporary document.** This file exists only to carry context across agent sessions on branch `117-feat-select-table-rows`. Delete it before or when the branch is merged. Do not reference it from other docs — the permanent architecture reference is `docs/frontend_refactor/DATA_TABLE.md`.

This document captures the full context and decisions for the row-selection and export feature on branch `117-feat-select-table-rows`.

**Status: Feature complete. Ready for PR. See Known Issues below for follow-on work.**

---

## What Was Built

### Visual / UX
- **Checkbox column** is the leftmost column in the data table.
- **All rows are checked by default** when the table loads or when filters change.
- **Select All / Deselect All buttons** sit above the table (outside the Turbo Frame, so they persist across page navigations). Styled as `rounded-full border border-neutral-400` pill buttons matching the rest of the app.
- **Export badge** on the Export button:
  - Shows `All` when everything is checked.
  - Shows a numeric count (e.g. `44,640`) when some rows have been unchecked.
  - Shows `0` when in none mode with nothing checked.
  - Hidden only when in all mode with some exclusions that reduce the count to zero (edge case).
- **Export button disabled state** when nothing is selected (none mode, `included.size === 0`):
  - Background swaps from green (`bg-[#67a25e]`) to gray (`bg-neutral-400`).
  - `cursor-not-allowed` applied.
  - `aria-disabled="true"` set.
  - Native `title` attribute set to `"Select at least one row to export"` (same pattern as `title="Opens in new tab"` on external links in the app).
- **Individual row unchecks persist across page navigation** — unchecking a row on page 1, navigating to page 2 and back, the row on page 1 is still unchecked.
- **Total count** is passed from the server via a `sr-only` span with `data-row-selection-target="totalCount"` inside the Turbo Frame, so the badge can compute `total − excluded`.

---

## State Model (`selection_state.js`)

This implements the **Inversion of Selection** (also called the **Implicit/Explicit Selection State**) pattern — an industry-standard approach used by Salesforce, AWS Console, and HubSpot for large paginated datasets.

### Modes

| Mode | `mode` value | Entered via |
|---|---|---|
| **All mode** | `"all"` | Default on load, `selectAll()`, filter change (`clear()`) |
| **None mode** | `"none"` | `deselectAll()` only |

### State transitions

```
[Page load / filter change]
        │
        ▼
  ┌─────────────────────────────────────────┐
  │  ALL MODE  (mode = "all")               │
  │  excluded = {}  ← empty = all checked   │
  │                                         │
  │  toggle(id) unchecked → excluded.add    │
  │  toggle(id) re-checked → excluded.del   │
  │                                         │
  │  isAllChecked() = excluded.size === 0   │
  └─────────────────────────────────────────┘
        │                     ▲
  deselectAll()          selectAll()
        │                     │
        ▼                     │
  ┌─────────────────────────────────────────┐
  │  NONE MODE  (mode = "none")             │
  │  included = {}  ← empty = none checked  │
  │                                         │
  │  toggle(id) checked   → included.add    │
  │  toggle(id) unchecked → included.del    │
  │                                         │
  │  isAllChecked() = always false          │
  └─────────────────────────────────────────┘
```

`isAllChecked()` and `isAllMode()` are **derived predicates**, not state. The actual source of truth is `mode` + `excluded` Set + `included` Set.

`excluded` and `included` are **Sets** (not Arrays) because the primary operation is membership testing (`has(id)`), which is O(1) on a Set vs O(n) on an Array. Sets also guarantee uniqueness by construction.

### Badge and export behavior

| Condition | Badge | Export sends |
|---|---|---|
| All mode, `excluded` empty (`isAllChecked()`) | `All` | Filter params only |
| All mode, some excluded | `total − excluded.size` (e.g. `44,637`) | Filter params + `exclude_pwsids[]` |
| None mode, `included` non-empty | `included.size` (e.g. `3`) | `pwsids[]` |
| None mode, `included` empty | `0` + button grayed out | no-op (return early) |

---

## Design Decision: Why the Inversion of Selection Pattern

**Decision:** Keep the Inversion of Selection / Implicit/Explicit Selection State approach. Do not implement a server-side ID fetch or an explicit-inclusion-only model.

**Network efficiency at every threshold:** If a user has 5,000 filtered rows and unchecks 3, we send 3 IDs — not 4,997. An explicit-inclusion-only approach requires sending 4,997 IDs for the same operation. The exclusion model outperforms at every realistic threshold, including past the 50% mark — at that point an inclusion-only model would already have been sending large payloads for every prior state.

**Matches user intent directly:** The mental model is "I want all of these *except* a few." The exclusion model maps to that intent without a translation step.

**No server state needed:** This is a public, session-less app. Keeping selection state client-side is the correct Hotwire philosophy: the server stays stateless, the frontend manages transient UI state.

**Filter-change paradox already solved:** `clear()` in `selection_state.js` resets to `mode = "all"` when filters change. This prevents exporting stale or unintended data — the same behavior production apps use.

**POST avoids URL length limits:** Filter params and ID lists never hit browser URL length limits.

**Rails array params over JSON encoding:** `exclude_pwsids[]` and `pwsids[]` are standard Rails array params handled cleanly by `strong_params`.

**Acknowledged trade-offs:** The server has two code paths (exclusion vs. inclusion). Both are simple ActiveRecord queries. The "tipping point" where a user unchecks the majority of rows making the exclusion list large is acknowledged but unrealistic in practice — and still outperforms the inclusion model at the same threshold.

---

## Export (`export_controller.js` + `exports_controller.rb`)

Three branches in `export_controller.js` (POST form submission):

1. **`isAllChecked()`** → send active filter params + search. Server: `apply_filters(params)` + `apply_search`.
2. **`isAllMode()` but NOT `isAllChecked()`** (some unchecked) → send filter params + search + `exclude_pwsids[]`. Server: `apply_filters(params)` + `apply_search` + `where.not(pwsid: exclude_pwsids)`.
3. **None mode** → send `pwsids[]` (explicitly checked IDs only). Server: `where(pwsid: ids)`. Empty `included` → return early, no submission.

All three paths also send `sort` and `direction`, so exported rows match the current table sort order.

Export always uses **POST** via a dynamically built `<form>` (with CSRF token) submitted and immediately removed.

**Important — sort/search are Turbo Frame params, not page URL params.** Sort header clicks and the search form navigate the `data-table` Turbo Frame only — they do not update `window.location`. `FilterState` (the JS singleton) also only tracks filter panel state, not sort or search. The solution: the server renders current sort/direction/search into a `#table-query-state` span inside the frame (`_table.html.erb`). This span re-renders on every frame navigation, so it always reflects the live state. `export_controller.js` reads from it directly.

---

## Streaming CSV Export

Both CSV and GeoJSON now use the same streaming Rack body pattern (`self.response_body = enumerator`). Neither sends `Content-Length` — the browser shows a live byte count as data arrives.

### Why `with_details` was removed from the CSV path

The old implementation called `base_scope.with_details` before passing the scope to the exporter. `with_details` is `includes(...)` over 8 associations — appropriate for single-record views (detail page, reports) where all associations are needed for one object. For a bulk export it materialises every AR object and all its associations into Ruby heap before writing a single CSV byte: a multi-hundred-MB allocation for a full dataset.

The new path never instantiates AR objects at all.

### Two-phase approach (sort preserved)

**Phase 1 — sorted ID pluck:** `@scope.pluck(:pwsid)` returns pwsids in the user's requested sort order. The scope already has `apply_sort_join` + `ORDER BY` applied by the controller. The pluck is a lightweight query (~2–4 MB of strings for the full dataset) that captures the correct ordering.

**Phase 2 — batched raw SQL:** The sorted IDs are sliced into `BATCH_SIZE`-element chunks. Each chunk is fetched via a single raw SQL query with all LEFT JOINs inline (`violations_summaries`, `demographics`, etc.) and `WHERE pws.pwsid IN (batch_ids)`. No AR objects are created. Within each batch the rows are re-sorted by the phase-1 order before streaming.

### Shared SQL structure

`ASSOCIATION_JOINS` is a frozen constant holding the LEFT JOIN clauses shared by both CSV and GeoJSON queries. GeoJSON adds one extra join (`service_area_geometries`) for geometry data; CSV does not need it. Both paths build their own SELECT clause on top of this shared base.

`CSV_EXPORT_COLUMNS` is the single source of truth — a frozen array of `[header, sql_expression]` pairs. Adding or reordering a column is a one-line edit in one place. Boolean columns use a `::text` cast so PG returns `"true"`/`"false"` rather than the pg wire format `"t"`/`"f"`. Note: this constant should be converted to a hash and renamed `CSV_COLUMN_MAP` — see Post-Merge Work below.

`BATCH_SIZE = 1000` matches the Rails `find_in_batches` default. Batching is explicit — `pluck` and raw `connection.execute` return all results in one shot without it.

### What changed in the controller

`ExportsController#create` is now two lines. Scope building is split into `build_export_scope` (applies sort) and `filtered_scope` (handles the three selection modes with a guard-clause early return for explicit IDs). `render_csv_export` mirrors `render_geojson_export`: sets `Content-Type` and `Content-Disposition` directly, assigns `self.response_body`. `send_data` is gone.

---

## Key Files

```
app/javascript/selection_state.js                              ← all selection state logic
app/javascript/controllers/row_selection_controller.js         ← Stimulus controller (checkboxes, badge, export button state)
app/javascript/controllers/export_controller.js                ← builds and submits POST form
app/controllers/public_water_systems/exports_controller.rb     ← create, filter/pwsids/exclude_pwsids + sort + search
app/controllers/concerns/sortable.rb                           ← SORTABLE_COLUMNS, TABLE_JOINS, sort/search methods shared by Home + Exports
spec/requests/exports_spec.rb                                  ← POST, all 3 export paths, sort ordering, search, filters
app/views/home/_table.html.erb                                 ← totalCount + table-query-state sr-only spans inside turbo-frame
app/views/home/index.html.erb                                  ← Select All/Deselect All buttons, badge span, export button, row-selection controller mount
app/components/ui/table_header_component.html.erb              ← check column renders empty <th> (no header checkbox)
app/components/ui/table_header_component.rb                    ← size: :check defined
```

---

## Stimulus Controller Wiring

```
data-controller="row-selection"                         → on wrapper div in index.html.erb
data-row-selection-target="countBadge"                 → the badge span inside Export button
data-row-selection-target="exportButton"               → the export <a> tag
data-row-selection-target="totalCount" data-count="N"  → sr-only span inside <turbo-frame> in _table.html.erb
data-row-selection-target="row" value="<pwsid>"        → each row checkbox in _table.html.erb (via render_table_cell)
data-action="click->row-selection#selectAll"           → Select All button in index.html.erb
data-action="click->row-selection#deselectAll"         → Deselect All button in index.html.erb
data-action="change->row-selection#toggle"             → each row checkbox
```

Export controller sits on a separate element inside the same wrapper:
```
data-controller="export"
data-export-url-value="<%= export_path %>"
data-action="click->export#download"                   → on the Export anchor tag
```

---

## Code Cleanup (Also Done This Session)

- **`check?` method removed** from `UI::TableHeaderComponent`. The template was `if check? (empty) / elsif sortable? / else label`. Since the check column has `label: nil` and `sort: nil`, `sortable?` is already false for it and `<%= nil %>` renders nothing — no special case needed. Simplified to `if sortable? / else @label / end`.
- **`perform_export` private method inlined** into `create`. It was only extracted to share between `show` and `create`. Once `show` was removed, the extraction was pure indirection.
- **GET export route and `show` action removed.** GET was the original export mechanism, kept alongside POST. Since `export_controller.js` always POSTs, GET was dead from the frontend. More importantly, GET silently breaks for large payloads (URL length limits) — the exact reason POST was introduced — making it a footgun to keep. Route is now `resource :export, only: :create`. GET export spec (`include_examples "CSV export", :get`) removed; 17 fewer examples (806 → 789).
- **CSV export rewritten as streaming raw SQL.** `to_csv` / `csv_row` (AR objects + `with_details`) replaced by `to_csv_stream` (two-phase pluck + batched raw SQL). `with_details` removed from the CSV controller path — it materialised every AR object and all 8 associations into Ruby heap before a single byte was sent. No AR objects are created in the new path.
- **`CSV_EXPORT_COLUMNS` replaces two parallel constants.** `CSV_HEADERS` and `CSV_COLUMNS` were separate 71-entry arrays with a manual "must stay in sync" requirement. Replaced by a single `[header, sql_expr]` source of truth; the two derived constants were removed entirely. Call sites use `CSV_EXPORT_COLUMNS.map(&:first)` (headers) and `CSV_EXPORT_COLUMNS.map(&:last).join(", ")` (SQL SELECT fragment) directly.
- **Export button color restored.** A rebase accidentally changed `bg-[#67a25e]` (green) to `bg-brand-primary` (blue) on the Export button. Fixed in both `index.html.erb` and the JS disabled-state toggle in `row_selection_controller.js`.
- **`ExportsController#create` refactored.** Replaced nested `if/else` scope building with `build_export_scope` + `filtered_scope` private methods and guard-clause style. The action is now two lines.

---

## Things That Were Tried and Reverted

- **Header checkbox (`selectAll` target in `<th>`)** — removed. Replaced by the two buttons above the table. The `<th>` for the check column now renders an empty cell.
- **`switchToExplicitExcluding`** — an approach that seeded the included set with current-page IDs on first uncheck. Reverted because navigating to other pages showed all rows unchecked (IDs not in the seeded set). The current exclusion model (`excluded` set, stays in `mode = "all"`) fixes this.
- **`totalCount` span outside `<turbo-frame>`** — placed wrong initially; Turbo only swaps content inside the frame, so the span never reached the DOM. Must be inside the `<turbo-frame>` element.
- **Styled tooltip on disabled export button** — tried using `tooltip_controller.js` (same as filter info icons) with empty `textValue` as a no-op. Reverted in favor of the native `title` attribute, which is consistent with `title="Opens in new tab"` used on external links elsewhere in the app.

---

## ~~Known Issues — Must Fix Before Merge~~ — All Resolved

- ~~`:pws` sentinel and `epa_report` source mismatch in `cell_value`~~ — **RESOLVED.** The `association` field on `TableColumn` was renamed to `source`; contract documented in both `columns.yml` and `table_column.rb`.

---

## Post-Merge Work

Ordered roughly by size — quick wins first, larger tracks last.

### ~~1. Convert `CSV_EXPORT_COLUMNS` to a hash — rename to `CSV_COLUMN_MAP`~~ — DONE

### ~~4. ColumnRegistry integration — unify export config with `columns.yml`~~ — DONE

Completed this session. Full details of the original plan are preserved above in git history.

**What was done:**
- `TableColumn` extended with four new fields: `csv_label`, `sql_expr`, `boolean`, `export_only`
- `ColumnRegistry` gains two new class methods: `csv_columns` and `geojson_columns`
- `columns.yml` annotated with `csv_label`, `sql_expr`, and `boolean: true` for all exported columns
- `population_pct_change` and `mhi_pct_change` added as full display-table entries (`source: trend_datum`)
- `PublicWaterSystemExporter`: `CSV_COLUMN_MAP` and `GEOJSON_PROPERTY_COLUMNS` constants removed; replaced with registry calls
- `HomeController`: `trend_datum` added to the preload list
- `config/brakeman.ignore`: fingerprint updated for the `col_map` false-positive in `fetch_csv_batch`

**Side-effects resolved:**
- `total_bwn` legacy name gone — GeoJSON property is now `total_notices`
- `is_grant_eligible` now included in GeoJSON (was previously missing)
- `row.values` ordering dependency in `to_csv_stream` eliminated

**816 examples, 0 failures. Brakeman, StandardRB, and tests all pass.**

---

### 2. Boil water notices — product decision pending

The boil water notices filter is UI-disabled in `app/views/home/_filter_menus.html.erb` with the label "(data unavailable)". The backend is fully wired: `Filterable#apply_boil_water_filters`, the `columns.yml` entry, and the `boil_water_summary` preload are all correct.

**The data quality issue:** `total_notices` is a raw cumulative count with no consistent time window across states. Ohio has data back to 1991; Maine only to 2025. Filtering on a raw count when windows are unequal is misleading. The `date_range_display` and `state_reporting_year_min/max` fields on `BoilWaterSummary` document this per-row, and are already surfaced on the detail page. The `tooltip_text` field (also stored) was never wired into the UI — `date_range_display` covers the same ground.

**Pending product decision:** Re-enable the filter as-is (useful within a state, potentially confusing cross-state), or keep it disabled and add a tooltip on the table column explaining the variable reporting window?

Once decided:
- **Re-enable:** Remove `disabled="disabled"` and the `(data unavailable)` label from `_filter_menus.html.erb`. No other code changes needed.
- **Add tooltip only:** Wire `date_range_display` or a static caveat into the table column header tooltip (same pattern as filter info icons).

### 3. Preload optimization — derive from visible columns

Every column-visibility change re-runs all association preload queries in `HomeController#table` even when the underlying data hasn't changed. At current scale this is imperceptible (25 rows, PG buffer cache), but the correct fix is:

```ruby
preloads = @columns.filter_map(&:source).reject { |s| s == :pws }.uniq
```

One-line change in `app/controllers/home_controller.rb`. Value is correctness over raw speed. Note: with `trend_datum` now in the fixed preload list, this optimization becomes slightly more worthwhile.

### ~~6. Manage Columns panel — grouped/nested column list~~ — DONE

**What was built:**

- `CategoryDef = Data.define(:key, :label)` value object (`app/columns/category_def.rb`)
- `TableColumn` extended with `:category` (Symbol or nil); every column entry in `columns.yml` explicitly declares `category:` (or `category: ~`), so no `initialize` default override is needed
- `config/columns.yml` gains a top-level `categories:` block (ordered list of `key`/`label` pairs) and a `category:` field on each column entry
- `ColumnRegistry.categories` — memoized class method returning `Array<CategoryDef>` in YAML-defined order; `reload!` and `yaml_config` updated accordingly
- `HomeController#index` sets `@column_categories = ColumnRegistry.categories`
- **3 ViewComponents** extracted for the manage-columns panel:
  - `ManageColumns::PinnedRowComponent` — always-visible disabled row
  - `ManageColumns::CategoryHeaderRowComponent` — category label + collapse/expand chevron button + toggle-all checkbox; yields child rows into a nested `<ul>`
  - `ManageColumns::ColumnRowComponent` — draggable checkbox row; `indented: true` shifts padding for category children; emits `data-category` and `syncCategoryState` action when the column has a category
- `manage_columns_controller.js` additions:
  - `toggleCategoryCollapse` — toggles `aria-expanded`, hides/shows child `<ul>` via `hidden`, rotates chevron `-rotate-90`; triggered by clicking anywhere on the header row (the label is inside the button)
  - `toggleCategory` — checks/unchecks all children AND syncs the collapse state (uncheck collapses, check expands)
  - `syncCategoryState` — updates the category header checkbox when an individual child changes
  - `#updateCategoryState` — sets header checked if ANY child is checked (matching filter panel convention); no indeterminate state
  - `#syncCheckboxesFromUrl` updated to also sync all category header states on panel open
- Categories defined in `columns.yml`: `utility_details`, `violations`, `demographics`, `environmental_justice`, `funding`, `watershed_hazards`
- `open_health_viol` moved from ungrouped to `category: violations`
- `config/environments/development.rb` — `config.watchable_files` extended with `columns.yml` and `filters.yml` so Zeitwerk triggers a reload when either config changes (previously required a server restart)

**Category grouping is purely a picker display concern — table column order is unchanged.**

### 7. Export respects column visibility — hidden columns excluded from CSV

Currently the CSV export always exports all columns regardless of what the user has hidden via the manage-columns panel. The correct behaviour is: export only the columns visible in the user's current table view (i.e. the same set returned by `visible_columns`).

**What needs to change:**
- The export POST form (built in `export_controller.js`) must include the current `cols=` param so the server knows the visible column set
- `ExportsController#create` must pass the visible column set to the exporter
- `PublicWaterSystemExporter#to_csv_stream` must accept a column list and use it to build the SELECT and headers instead of always calling `ColumnRegistry.csv_columns`
- Columns with no `sql_expr` (e.g. `:check`, `:epa_report` link) must be skipped gracefully

Note: GeoJSON export should probably remain full-fidelity (all columns) since it is consumed programmatically. The `cols=` scoping applies to CSV only.

### 5. Drag-and-drop column reordering

The drag handles are visible in the manage-columns modal but not wired. The `cols=` URL param format already supports ordering. `visible_columns` needs to respect param order rather than registry order:

```ruby
def visible_columns
  return ColumnRegistry.columns if params[:cols].blank?
  ordered_keys = params[:cols].split(",").map(&:to_sym)
  always_first = ColumnRegistry.columns.select { |c| c.pinned }
  rest = ordered_keys.filter_map { |k| ColumnRegistry.columns.find { |c| c.key == k } }
  always_first + rest
end
```

Wire SortableJS on the manage-columns panel `<ul>` so drag reordering updates the `data-col-key` checkbox order before `serializeCols` runs. See `docs/DRAG_DROP_SORTABLE_JS.md`.

---

## CI Status

248 component + column + helper examples, 0 failures (last run this session). Full suite was last confirmed green at 816 examples before the manage-columns work; component specs add ~32 new examples on top of that. Style, Brakeman, and tests all pass. Only Puma CVE (gem audit) remains — deferred, not blocking.

**Note — sort fix needs manual verification.** The request specs confirm the server correctly applies sort/search when params are present. The JS side (`export_controller.js` reading from `#table-query-state`) cannot be covered by request specs — it requires a browser. Verify manually: sort the table by a non-default column, click Export, confirm the downloaded CSV rows are in the sorted order.

**Note — Export button green colour needs manual verification.** The `bg-[#67a25e]` fix was applied to both the HTML and the JS disabled-state toggle, but should be visually confirmed in the browser: (1) default state is green, (2) Deselect All greys the button, (3) Select All restores green.

## Next Session

Remaining open items in priority order:

1. **URL state persistence — cols + sort survive filter changes and navigation (item 9 below)** — JS + ERB refactor, no backend changes. Start here.
2. **Preload optimization (item 3)** — one-line change in `HomeController#table`, low risk.
3. **Export respects column visibility (item 7)** — requires JS + controller + exporter changes.
4. **BWN filter (item 2)** — awaiting product decision. One-line fix once decided.
5. **Drag-and-drop reordering (item 5)** — larger JS + Ruby change; see `docs/DRAG_DROP_SORTABLE_JS.md`.

---

### ~~8. Indeterminate (`−`) state for category header checkboxes~~ — DONE

**What was done:**

`manage_columns_controller.js` `#updateCategoryState`:
```js
const checkedCount = children.filter(cb => cb.checked).length
header.checked = checkedCount === children.length
header.indeterminate = checkedCount > 0 && checkedCount < children.length
```

`filter_controller.js` `syncParentFromSubcat` (violations subcat panel parent sync):
```js
const checkedCount = filter.subcats.filter(s => document.getElementById(s.id)?.checked).length
if (parentEl) {
  parentEl.checked = checkedCount === filter.subcats.length
  parentEl.indeterminate = checkedCount > 0 && checkedCount < filter.subcats.length
}
```

`filter_controller.js` `subcat_panel` URL restoration: parent sync moved to **after** the per-subcat forEach loop so it reads actual checked state rather than always forcing `checked = true`.

Filter panel toggle arrows also aligned to match columns convention (↓ open, → closed) by changing `rotate-180` to `-rotate-90` in `#setToggleArrow` and the reset block, and adding `-rotate-90` as the initial class on all closed-state arrow icons in `_filter_menus.html.erb` and `group_range_component.html.erb`.

---

### 9. URL state persistence — cols + sort survive filter changes and navigation

**The problem:**

Column choices (`cols=`) and sort choices (`sort=`, `direction=`) are currently lost whenever:
- The user applies or changes a filter
- The user navigates away (map) and back to the table

**Root cause — two places in `filter_controller.js`:**

1. **`#syncToUrl()`** (line ~543): replaces the entire URL search string with only filter params:
   ```js
   url.search = FilterState.toUrlParams().toString()
   ```
   This clobbers any `cols`, `sort`, or `direction` params already in the URL.

2. **`#visitTableFrame()`** (line ~631): builds the table URL from filter state only:
   ```js
   Turbo.visit(`/table?${FilterState.toUrlParams()}`, { frame: "data-table" })
   ```
   Even if the URL had `cols` before `#syncToUrl` ran, `#visitTableFrame` ignores it.

**Additionally — `serializeCols` uses a form submission hack:**

The manage-columns panel uses an HTML form with a hidden `cols` input and a `disabled` trick to conditionally omit the param. This is not idiomatic — it should use `Turbo.visit` directly like `#visitTableFrame` does for filter changes.

**The fix — three changes, no new modules:**

The URL is the single source of truth. The strategy is: always keep `cols`, `sort`, and `direction` in the URL; have both `#syncToUrl` and `#visitTableFrame` treat them as pass-through params they preserve but don't own.

**Change 1 — `filter_controller.js` `#syncToUrl`:**

Preserve display params when replacing filter params in the URL. Currently:
```js
url.search = FilterState.toUrlParams().toString()
```
Replace with:
```js
const displayParams = ["cols", "sort", "direction"]
const preserved = {}
displayParams.forEach(key => {
  const val = url.searchParams.get(key)
  if (val !== null) preserved[key] = val
})
url.search = FilterState.toUrlParams().toString()
Object.entries(preserved).forEach(([key, val]) => url.searchParams.set(key, val))
```

**Change 2 — `filter_controller.js` `#visitTableFrame`:**

Since the URL now always has the complete state (filters + display params), simply visit it:
```js
#visitTableFrame() {
  Turbo.visit(window.location.href, { frame: "data-table" })
}
```

**Change 3 — `manage_columns_controller.js` + `app/views/home/index.html.erb`:**

Replace the form-submission approach with `Turbo.visit`. The form existed only to submit to the `data-table` Turbo frame — that job now belongs to `Turbo.visit` directly.

In `manage_columns_controller.js`:
- Remove `"colsInput"` from `static targets`
- Remove `#updateUrl` private method (inlined into the new helper)
- Replace `serializeCols` and `reset` with a shared `#applyAndVisit(keys)` private helper:

```js
serializeCols() {
  const allBoxes = this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]')
  const checkedKeys = Array.from(allBoxes).filter(cb => cb.checked).map(cb => cb.dataset.colKey)
  const keys = checkedKeys.length === allBoxes.length ? null : checkedKeys.join(",")
  this.#applyAndVisit(keys)
}

reset() {
  this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]').forEach(cb => cb.checked = true)
  this.#applyAndVisit(null)
}

#applyAndVisit(keys) {
  const url = new URL(window.location)
  keys === null ? url.searchParams.delete("cols") : url.searchParams.set("cols", keys)
  history.replaceState({}, "", url)
  this.#close()
  Turbo.visit(url.toString(), { frame: "data-table" })
}
```

Also update `#syncCheckboxesFromUrl` — the current `cols ? ...` check treats empty string as falsy (same as absent). Use strict `!== null` so an explicitly-empty `cols=` param correctly unchecks all optional columns:
```js
const visibleKeys = cols !== null ? new Set(cols.split(",").filter(Boolean)) : null
```

In `app/views/home/index.html.erb`, on the manage-columns `<form>`:
- Remove `data-action="submit->manage-columns#serializeCols"`
- Remove `data-turbo-frame="data-table"`
- Remove `action="<%= table_path %>"` and `method="get"`
- Remove `<%= hidden_inputs_for_params(except: ["cols"]) %>`
- Remove `<input type="hidden" name="cols" data-manage-columns-target="colsInput">`
- Change the "Show Columns" submit button to `type="button"` with `data-action="click->manage-columns#serializeCols"`

The `<form>` element itself can remain as a semantic wrapper for the checkboxes, just without submission attributes.

**Backend — `home_controller.rb` (already done earlier this session):**

`params[:cols].blank?` was changed to `params[:cols].nil?` in both `index` and `visible_columns`. This correctly distinguishes:
- `nil` (param absent) → show all columns (default)
- `""` (param present, empty) → show only pinned columns
- `"pwsid,stusps"` → show that explicit set

**Reset behavior (independent):**
- **Filter reset** (`filter_controller.js` `#resetMenu`): resets filter state only — `cols`, `sort`, `direction` remain in URL, table reloads with column/sort choices intact.
- **Column reset** (`manage_columns_controller.js` `reset()`): calls `#applyAndVisit(null)` which deletes the `cols` param — filters and sort remain, only column visibility resets to all.

**Key files:**
- `app/javascript/controllers/filter_controller.js` — `#syncToUrl` and `#visitTableFrame`
- `app/javascript/controllers/manage_columns_controller.js` — `serializeCols`, `reset`, `#applyAndVisit`, `#syncCheckboxesFromUrl`
- `app/views/home/index.html.erb` — manage-columns form attributes + hidden inputs
